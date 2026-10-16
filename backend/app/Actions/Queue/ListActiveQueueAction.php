<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;

/**
 * Action métier : Récupération des demandes actives du jour pour la file d'attente (F02 / CA3, F04 / CA12, CA22).
 *
 * Filtres :
 *  - Même école (school_id)
 *  - Si rôle surveillant (F04 / Q2) :
 *      - Statut class_notified uniquement
 *      - Tri par called_at ASC
 *  - Si concierge ou director (F02) :
 *      - Statuts actifs (requested, class_notified, on_the_way, pending_agent_confirmation)
 *      - Tri par created_at ASC
 *  - Demandes créées durant la journée en cours à Casablanca (Africa/Casablanca)
 *  - Eager loading de l'enfant (child)
 */
class ListActiveQueueAction
{
    /**
     * @return Collection<int, PickupRequest>
     */
    public function handle(School $school, ?User $user = null): Collection
    {
        $startOfDay = Carbon::now('Africa/Casablanca')->startOfDay();
        $endOfDay = Carbon::now('Africa/Casablanca')->endOfDay();

        $query = PickupRequest::where('school_id', $school->id)
            ->where('created_at', '>=', $startOfDay)
            ->where('created_at', '<=', $endOfDay)
            ->with('child');

        if ($user && $user->role === 'surveillant') {
            return $query->where('status', PickupRequest::STATUS_CLASS_NOTIFIED)
                ->orderBy('called_at', 'asc')
                ->get();
        }

        return $query->whereIn('status', [
            PickupRequest::STATUS_REQUESTED,
            PickupRequest::STATUS_CLASS_NOTIFIED,
            PickupRequest::STATUS_ON_THE_WAY,
            PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
        ])
            ->orderBy('created_at', 'asc')
            ->get();
    }
}
