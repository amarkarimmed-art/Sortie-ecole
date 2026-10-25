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

            // Justifié : Classes assignées au surveillant avec filtrage explicite de l'école
            $assignedClasses = $user->schoolClasses()->withoutGlobalScopes()
                ->where('school_classes.school_id', $school->id)
                ->get();

            $assignedClassIds = $assignedClasses->pluck('id')->filter()->all();
            $assignedClassNames = $assignedClasses->pluck('name')
                ->filter()
                ->map(fn ($n) => strtolower(trim((string) $n)))
                ->all();

            $activeStatuses = [
                'arrived',
                PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
                PickupRequest::STATUS_REQUESTED,
                PickupRequest::STATUS_CLASS_NOTIFIED,
                PickupRequest::STATUS_ON_THE_WAY,
            ];

            // Si aucune classe n'est assignée à ce surveillant, il accède à toute la file active de son école
            if (empty($assignedClassIds) && empty($assignedClassNames)) {
                return $query->whereIn('status', $activeStatuses)
                    ->orderBy('created_at', 'asc')
                    ->get();
            }

            $hasSchoolClassIdCol = \Illuminate\Support\Facades\Schema::hasColumn('children', 'school_class_id');

            return $query->whereIn('status', $activeStatuses)
                ->whereHas('child', function ($cq) use ($assignedClassIds, $assignedClassNames, $hasSchoolClassIdCol) {
                    $cq->where(function ($inner) use ($assignedClassIds, $assignedClassNames, $hasSchoolClassIdCol) {
                        $hasCondition = false;
                        if ($hasSchoolClassIdCol && ! empty($assignedClassIds)) {
                            $inner->whereIn('children.school_class_id', $assignedClassIds);
                            $hasCondition = true;
                        }
                        if (! empty($assignedClassNames)) {
                            $placeholders = implode(',', array_fill(0, count($assignedClassNames), '?'));
                            $method = $hasCondition ? 'orWhereRaw' : 'whereRaw';
                            $inner->$method("LOWER(TRIM(children.class_name)) IN ({$placeholders})", $assignedClassNames);
                        }
                    });
                })
                ->orderBy('created_at', 'asc')
                ->get();
        }

        return $query->whereIn('status', [
            'arrived',
            PickupRequest::STATUS_REQUESTED,
            PickupRequest::STATUS_CLASS_NOTIFIED,
            PickupRequest::STATUS_ON_THE_WAY,
            PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
        ])
            ->orderBy('created_at', 'asc')
            ->get();
    }
}
