<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Events\PickupRequestDeparted;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Models\PickupRequest;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;

class MarkDepartAction
{
    /**
     * Marquer le départ d'une demande de sortie (transition class_notified -> on_the_way).
     *
     * @throws HandoverImpossibleException
     */
    public function handle(
        PickupRequest $pickupRequest,
        User $marker,
        string $idempotencyKey
    ): PickupRequest {
        // 0. Contrôle d'isolation multi-école
        if ((string) $pickupRequest->school_id !== (string) $marker->school_id) {
            throw new ModelNotFoundException('Demande introuvable pour cette école.');
        }

        // 1. Contrôle préalable : idempotence d'état si déjà on_the_way (CA7)
        if ($pickupRequest->status === PickupRequest::STATUS_ON_THE_WAY) {
            return $pickupRequest;
        }

        // 2. Statut invalide (doit être class_notified ; requested -> 422 CA19, terminaux -> 422 CA9)
        if ($pickupRequest->status !== PickupRequest::STATUS_CLASS_NOTIFIED) {
            throw new HandoverImpossibleException(
                "Impossible de marquer le départ pour une demande au statut '{$pickupRequest->status}'."
            );
        }

        // 3. Verrouillage pessimiste sous transaction
        return DB::transaction(function () use ($pickupRequest, $marker) {
            $locked = PickupRequest::where('id', $pickupRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->status === PickupRequest::STATUS_ON_THE_WAY) {
                return $locked;
            }

            if ($locked->status !== PickupRequest::STATUS_CLASS_NOTIFIED) {
                throw new HandoverImpossibleException(
                    "Impossible de marquer le départ pour une demande au statut '{$locked->status}'."
                );
            }

            $now = Carbon::now('Africa/Casablanca');

            $locked->update([
                'status' => PickupRequest::STATUS_ON_THE_WAY,
                'departed_by_user_id' => $marker->id,
                'departed_at' => $now,
            ]);

            $locked->load('child');
            PickupRequestDeparted::dispatch($locked);

            return $locked;
        });
    }
}
