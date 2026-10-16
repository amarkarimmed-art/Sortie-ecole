<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Events\PickupRequestDeparted;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Exceptions\Queue\IdempotencyConflictException;
use App\Models\IdempotencyKey;
use App\Models\PickupRequest;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

class MarkDepartAction
{
    /**
     * Marquer le départ d'une demande de sortie (transition class_notified -> on_the_way).
     *
     * @param  array<string, mixed>  $requestPayload
     * @return array<string, mixed>
     *
     * @throws HandoverImpossibleException
     * @throws IdempotencyConflictException
     */
    public function handle(
        PickupRequest $pickupRequest,
        User $marker,
        string $idempotencyKey,
        array $requestPayload = []
    ): array {
        // 0. Contrôle d'isolation multi-école
        if ((string) $pickupRequest->school_id !== (string) $marker->school_id) {
            throw new ModelNotFoundException('Demande introuvable pour cette école.');
        }

        $keyHash = hash('sha256', $idempotencyKey);
        $requestHash = hash('sha256', json_encode($requestPayload) ?: '{}');
        $endpoint = 'POST /depart';

        // 1. Vérification d'idempotence persistée
        $existing = IdempotencyKey::where('user_id', $marker->id)
            ->where('key_hash', $keyHash)
            ->where('endpoint', $endpoint)
            ->first();

        if ($existing) {
            if ($existing->request_hash === $requestHash) {
                return $existing->response_body;
            }

            throw new IdempotencyConflictException;
        }

        // 2. Contrôle préalable : idempotence d'état si déjà on_the_way (CA7)
        if ($pickupRequest->status === PickupRequest::STATUS_ON_THE_WAY) {
            $responseBody = [
                'id' => (string) $pickupRequest->id,
                'status' => $pickupRequest->status,
                'updated_at' => $pickupRequest->updated_at?->toISOString() ?? Carbon::now('Africa/Casablanca')->toISOString(),
            ];

            try {
                IdempotencyKey::create([
                    'user_id' => $marker->id,
                    'key_hash' => $keyHash,
                    'request_hash' => $requestHash,
                    'endpoint' => $endpoint,
                    'response_status' => 200,
                    'response_body' => $responseBody,
                ]);
            } catch (UniqueConstraintViolationException) {
                // Clé insérée en concurrence
            }

            return $responseBody;
        }

        // 3. Statut invalide (doit être class_notified ; requested -> 422 CA19, terminaux -> 422 CA9)
        if ($pickupRequest->status !== PickupRequest::STATUS_CLASS_NOTIFIED) {
            throw new HandoverImpossibleException(
                "Impossible de marquer le départ pour une demande au statut '{$pickupRequest->status}'."
            );
        }

        // 4. Verrouillage pessimiste sous transaction
        return DB::transaction(function () use ($pickupRequest, $marker, $keyHash, $requestHash, $endpoint) {
            $locked = PickupRequest::where('id', $pickupRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->status === PickupRequest::STATUS_ON_THE_WAY) {
                $responseBody = [
                    'id' => (string) $locked->id,
                    'status' => $locked->status,
                    'updated_at' => $locked->updated_at?->toISOString() ?? Carbon::now('Africa/Casablanca')->toISOString(),
                ];

                try {
                    IdempotencyKey::create([
                        'user_id' => $marker->id,
                        'key_hash' => $keyHash,
                        'request_hash' => $requestHash,
                        'endpoint' => $endpoint,
                        'response_status' => 200,
                        'response_body' => $responseBody,
                    ]);
                } catch (UniqueConstraintViolationException) {
                    // Clé insérée en concurrence
                }

                return $responseBody;
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

            $responseBody = [
                'id' => (string) $locked->id,
                'status' => $locked->status,
                'updated_at' => $locked->updated_at?->toISOString() ?? $now->toISOString(),
            ];

            try {
                IdempotencyKey::create([
                    'user_id' => $marker->id,
                    'key_hash' => $keyHash,
                    'request_hash' => $requestHash,
                    'endpoint' => $endpoint,
                    'response_status' => 200,
                    'response_body' => $responseBody,
                ]);
            } catch (UniqueConstraintViolationException) {
                // Clé insérée en concurrence
            }

            return $responseBody;
        });
    }
}
