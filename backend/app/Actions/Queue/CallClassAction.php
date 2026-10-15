<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Events\PickupRequestCalled;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Models\PickupRequest;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Support\Facades\DB;

class CallClassAction
{
    /**
     * Appeler une classe pour une demande de sortie (transition requested -> class_notified).
     *
     * @throws HandoverImpossibleException
     */
    public function handle(
        PickupRequest $pickupRequest,
        User $caller,
        string $idempotencyKey
    ): PickupRequest {
        // 0. Contrôle d'isolation multi-école
        if ((string) $pickupRequest->school_id !== (string) $caller->school_id) {
            throw new ModelNotFoundException('Demande introuvable pour cette école.');
        }

        // 1. Contrôle préalable : idempotence d'état si déjà class_notified (CA10)
        if ($pickupRequest->status === PickupRequest::STATUS_CLASS_NOTIFIED) {
            return $pickupRequest;
        }

        // 2. Statut invalide (terminaux ou non éligibles -> 422, CA9/Q5)
        if ($pickupRequest->status !== PickupRequest::STATUS_REQUESTED) {
            throw new HandoverImpossibleException(
                "Impossible d'appeler la classe pour une demande au statut '{$pickupRequest->status}'."
            );
        }

        // 3. Verrouillage pessimiste sous transaction
        return DB::transaction(function () use ($pickupRequest, $caller) {
            $locked = PickupRequest::where('id', $pickupRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->status === PickupRequest::STATUS_CLASS_NOTIFIED) {
                return $locked;
            }

            if ($locked->status !== PickupRequest::STATUS_REQUESTED) {
                throw new HandoverImpossibleException(
                    "Impossible d'appeler la classe pour une demande au statut '{$locked->status}'."
                );
            }

            $now = Carbon::now('Africa/Casablanca');

            $locked->update([
                'status' => PickupRequest::STATUS_CLASS_NOTIFIED,
                'called_by_user_id' => $caller->id,
                'called_at' => $now,
            ]);

            $locked->load('child');
            PickupRequestCalled::dispatch($locked);

            return $locked;
        });
    }
}
