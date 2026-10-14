<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Models\PickupRequest;
use App\Models\School;
use Carbon\Carbon;
use Illuminate\Support\Collection;

/**
 * Action métier : Récupération des demandes actives du jour pour la file d'attente (F02 / CA3).
 *
 * Filtres :
 *  - Même école (school_id)
 *  - Statuts actifs uniquement (requested, class_notified, on_the_way, pending_agent_confirmation)
 *  - Demandes créées durant la journée en cours à Casablanca (Africa/Casablanca)
 *  - Eager loading de l'enfant (child)
 *  - Tri chronologique ascendant (created_at ASC)
 */
class ListActiveQueueAction
{
    /**
     * @return Collection<int, PickupRequest>
     */
    public function handle(School $school): Collection
    {
        $startOfDay = Carbon::now('Africa/Casablanca')->startOfDay();
        $endOfDay = Carbon::now('Africa/Casablanca')->endOfDay();

        return PickupRequest::where('school_id', $school->id)
            ->whereIn('status', [
                PickupRequest::STATUS_REQUESTED,
                PickupRequest::STATUS_CLASS_NOTIFIED,
                PickupRequest::STATUS_ON_THE_WAY,
                PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
            ])
            ->where('created_at', '>=', $startOfDay)
            ->where('created_at', '<=', $endOfDay)
            ->with('child')
            ->orderBy('created_at', 'asc')
            ->get();
    }
}
