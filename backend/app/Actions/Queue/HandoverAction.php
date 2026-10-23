<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Exceptions\Queue\HandoverDejaEnregistreException;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Models\HandoverLog;
use App\Models\PickupRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class HandoverAction
{
    /**
     * Valider la remise d'un enfant et enregistrer l'entrée immuable.
     *
     * Machine à états B2 : transitions autorisées vers handed_over
     * depuis requested, class_notified, on_the_way, pending_agent_confirmation.
     *
     * @throws HandoverImpossibleException
     * @throws HandoverDejaEnregistreException
     */
    public function handle(
        PickupRequest $request,
        User $agent,
        string $idempotencyKey,
        string $collectorType,
        ?string $collectorId = null
    ): HandoverLog {
        // 0. Contrôle d'isolation multi-école (défense en profondeur)
        if ((string) $request->school_id !== (string) $agent->school_id) {
            throw new ModelNotFoundException('Demande introuvable pour cette école.');
        }

        // 0b. Vérification des classes assignées pour le rôle surveillant
        if ($agent->role === 'surveillant') {
            // Justifié : Vérification de l'existence des classes pour l'école
            $schoolHasClasses = \App\Models\SchoolClass::withoutGlobalScopes()
                ->where('school_id', $request->school_id)
                ->exists();

            if ($schoolHasClasses) {
                $request->loadMissing('child');
                $childClassName = trim((string) ($request->child?->class_name ?? ''));
                // Justifié : Classes assignées au surveillant filtrées par école
                $assignedClasses = $agent->schoolClasses()->withoutGlobalScopes()
                    ->where('school_classes.school_id', $request->school_id)
                    ->pluck('school_classes.name')
                    ->map(fn ($n) => trim((string) $n))
                    ->all();

                if (! in_array($childClassName, $assignedClasses, true)) {
                    abort(403, "Le surveillant n'est pas autorisé pour la classe '{$childClassName}'.");
                }
            }
        }

        // a. Vérifier si une remise a déjà été effectuée avec cette idempotency_key (rejeu réseau idempotent)
        $existingLog = HandoverLog::where('idempotency_key', $idempotencyKey)->first();
        if ($existingLog) {
            throw new HandoverDejaEnregistreException($existingLog);
        }

        // b. Vérifier que la demande est dans un statut actif éligible (B2)
        $activeStatuses = [
            PickupRequest::STATUS_REQUESTED,
            PickupRequest::STATUS_CLASS_NOTIFIED,
            PickupRequest::STATUS_ON_THE_WAY,
            PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
        ];

        if (! in_array($request->status, $activeStatuses, true)) {
            throw new HandoverImpossibleException(
                "Impossible d'effectuer une remise pour une demande au statut '{$request->status}'."
            );
        }

        // c. Enregistrement en transaction DB avec verrouillage pessimiste et gestion de la concurrence
        try {
            return DB::transaction(function () use ($request, $agent, $idempotencyKey, $collectorType, $collectorId, $activeStatuses) {
                $locked = PickupRequest::where('id', $request->id)
                    ->lockForUpdate()
                    ->firstOrFail();

                if (! in_array($locked->status, $activeStatuses, true)) {
                    throw new HandoverImpossibleException(
                        "Impossible d'effectuer une remise pour une demande au statut '{$locked->status}'."
                    );
                }

                $parentUserId = ($collectorType === HandoverLog::COLLECTOR_PARENT)
                    ? ($collectorId ?? $locked->requested_by)
                    : null;

                $authorizedPersonId = ($collectorType === HandoverLog::COLLECTOR_AUTHORIZED_PERSON)
                    ? $collectorId
                    : null;

                $log = HandoverLog::create([
                    'id' => (string) Str::uuid(),
                    'school_id' => $locked->school_id,
                    'pickup_request_id' => $locked->id,
                    'agent_id' => $agent->id,
                    'collector_type' => $collectorType,
                    'parent_user_id' => $parentUserId,
                    'authorized_person_id' => $authorizedPersonId,
                    'idempotency_key' => $idempotencyKey,
                ]);

                $locked->update([
                    'status' => PickupRequest::STATUS_HANDED_OVER,
                ]);

                if ($locked->requested_by) {
                    try {
                        $locked->loadMissing('child');
                        $child = $locked->child;
                        $childName = trim("{$child?->first_name} {$child?->last_name}");
                        event(new \App\Events\ParentPickupStatusUpdated(
                            requestId: (string) $locked->id,
                            schoolId: (string) $locked->school_id,
                            parentUserId: (string) $locked->requested_by,
                            childId: (string) $locked->child_id,
                            childName: $childName,
                            status: PickupRequest::STATUS_HANDED_OVER,
                            updatedAt: $locked->updated_at?->toISOString() ?? \Carbon\Carbon::now('Africa/Casablanca')->toISOString(),
                        ));
                    } catch (\Throwable) {
                    }
                }

                return $log;
            });
        } catch (UniqueConstraintViolationException $e) {
            $existing = HandoverLog::where('idempotency_key', $idempotencyKey)->first();
            if ($existing) {
                throw new HandoverDejaEnregistreException($existing);
            }

            throw $e;
        }
    }
}
