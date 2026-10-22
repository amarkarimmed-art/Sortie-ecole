<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Exceptions\Queue\HandoverImpossibleException;
use App\Models\PickupRequest;

class ConfirmPresenceAction
{
    /**
     * Valider manuellement la présence d'un parent hors rayon (pending_agent_confirmation -> requested).
     *
     * @throws HandoverImpossibleException
     */
    public function handle(PickupRequest $request): PickupRequest
    {
        if ($request->status !== PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION) {
            throw new HandoverImpossibleException(
                'Seule une demande en attente de confirmation agent peut être confirmée.'
            );
        }

        $request->update([
            'status' => PickupRequest::STATUS_REQUESTED,
        ]);

        if ($request->requested_by) {
            try {
                $request->loadMissing('child');
                $child = $request->child;
                $childName = trim("{$child?->first_name} {$child?->last_name}");
                event(new \App\Events\ParentPickupStatusUpdated(
                    requestId: (string) $request->id,
                    schoolId: (string) $request->school_id,
                    parentUserId: (string) $request->requested_by,
                    childId: (string) $request->child_id,
                    childName: $childName,
                    status: PickupRequest::STATUS_REQUESTED,
                    updatedAt: $request->updated_at?->toISOString() ?? \Carbon\Carbon::now('Africa/Casablanca')->toISOString(),
                ));
            } catch (\Throwable) {
            }
        }

        return $request;
    }
}
