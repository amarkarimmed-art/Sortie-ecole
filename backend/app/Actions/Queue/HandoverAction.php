<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Exceptions\Queue\HandoverDejaEnregistreException;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Models\HandoverLog;
use App\Models\PickupRequest;
use App\Models\User;
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

        // c. Enregistrement en transaction DB
        return DB::transaction(function () use ($request, $agent, $idempotencyKey, $collectorType, $collectorId) {
            $parentUserId = ($collectorType === HandoverLog::COLLECTOR_PARENT)
                ? ($collectorId ?? $request->requested_by)
                : null;

            $authorizedPersonId = ($collectorType === HandoverLog::COLLECTOR_AUTHORIZED_PERSON)
                ? $collectorId
                : null;

            $log = HandoverLog::create([
                'id' => (string) Str::uuid(),
                'school_id' => $request->school_id,
                'pickup_request_id' => $request->id,
                'agent_id' => $agent->id,
                'collector_type' => $collectorType,
                'parent_user_id' => $parentUserId,
                'authorized_person_id' => $authorizedPersonId,
                'idempotency_key' => $idempotencyKey,
            ]);

            $request->update([
                'status' => PickupRequest::STATUS_HANDED_OVER,
            ]);

            return $log;
        });
    }
}
