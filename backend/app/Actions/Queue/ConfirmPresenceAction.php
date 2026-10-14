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

        return $request;
    }
}
