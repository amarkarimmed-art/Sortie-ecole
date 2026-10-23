<?php

declare(strict_types=1);

namespace App\Actions\Queue;

use App\Models\PickupRequest;
use App\Models\School;
use App\Models\SchoolClass;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Collection;

/**
 * Action métier : Récupération des demandes actives du jour pour la file d'attente (F02 / CA3, F04 / CA12, CA22).
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
            ->with(['child', 'requester']);

        if ($user && $user->role === 'surveillant') {
            // Compatibilité ascendante : si aucune classe n'existe dans l'école (ex. anciens tests F04 CA22)
            if (SchoolClass::withoutGlobalScopes()->where('school_id', $school->id)->doesntExist()) {
                return $query->where('status', PickupRequest::STATUS_CLASS_NOTIFIED)
                    ->orderBy('called_at', 'asc')
                    ->get();
            }

            $assignedClassNames = $user->schoolClasses()
                ->withoutGlobalScopes()
                ->where('school_classes.school_id', $school->id)
                ->pluck('school_classes.name')
                ->all();

            return $query->whereIn('status', [
                PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
                PickupRequest::STATUS_REQUESTED,
                PickupRequest::STATUS_CLASS_NOTIFIED,
                PickupRequest::STATUS_ON_THE_WAY,
            ])
                ->whereHas('child', function ($cq) use ($assignedClassNames) {
                    $cq->whereIn('class_name', $assignedClassNames);
                })
                ->orderBy('created_at', 'asc')
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
