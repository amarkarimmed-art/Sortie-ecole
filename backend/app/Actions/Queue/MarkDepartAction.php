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

        // 0b. Vérification des classes assignées au surveillant
        if ($marker->role === 'surveillant') {
            $schoolHasClasses = \App\Models\SchoolClass::withoutGlobalScopes()
                ->where('school_id', $pickupRequest->school_id)
                ->exists();

            if ($schoolHasClasses) {
                $pickupRequest->loadMissing('child');
                $childClassName = trim((string) ($pickupRequest->child?->class_name ?? ''));
                $assignedClasses = $marker->schoolClasses()
                    ->withoutGlobalScopes()
                    ->where('school_classes.school_id', $pickupRequest->school_id)
                    ->pluck('school_classes.name')
                    ->map(fn ($n) => trim((string) $n))
                    ->all();

                if (! in_array($childClassName, $assignedClasses, true)) {
                    abort(403, "Le surveillant n'est pas autorisé pour la classe '{$childClassName}'.");
                }
            }
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

        // 2. Contrôle préalable : idempotence d'état si déjà on_the_way ou handed_over
        if ($pickupRequest->status === PickupRequest::STATUS_ON_THE_WAY || $pickupRequest->status === PickupRequest::STATUS_HANDED_OVER) {
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

        // 3. Statuts autorisés pour transition vers on_the_way :
        // requested, pending_agent_confirmation, class_notified
        $validStatuses = [
            PickupRequest::STATUS_REQUESTED,
            PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
            PickupRequest::STATUS_CLASS_NOTIFIED,
        ];

        if (! in_array($pickupRequest->status, $validStatuses, true)) {
            throw new HandoverImpossibleException(
                "Impossible de marquer le départ pour une demande au statut '{$pickupRequest->status}'."
            );
        }

        // 4. Verrouillage pessimiste sous transaction
        return DB::transaction(function () use ($pickupRequest, $marker, $keyHash, $requestHash, $endpoint, $validStatuses) {
            $locked = PickupRequest::where('id', $pickupRequest->id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($locked->status === PickupRequest::STATUS_ON_THE_WAY || $locked->status === PickupRequest::STATUS_HANDED_OVER) {
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

            if (! in_array($locked->status, $validStatuses, true)) {
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

            if ($locked->requested_by) {
                try {
                    $child = $locked->child;
                    $childName = trim("{$child?->first_name} {$child?->last_name}");
                    event(new \App\Events\ParentPickupStatusUpdated(
                        requestId: (string) $locked->id,
                        schoolId: (string) $locked->school_id,
                        parentUserId: (string) $locked->requested_by,
                        childId: (string) $locked->child_id,
                        childName: $childName,
                        status: PickupRequest::STATUS_ON_THE_WAY,
                        updatedAt: $locked->updated_at?->toISOString() ?? $now->toISOString(),
                    ));
                } catch (\Throwable) {
                }
            }

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
