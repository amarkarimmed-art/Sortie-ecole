<?php

declare(strict_types=1);

namespace App\Actions\Arrival;

use App\Actions\BaseAction;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use App\Repositories\Contracts\ArrivalRepositoryInterface;
use Carbon\Carbon;

/**
 * Action métier : Consultation du statut de l'arrivée courante d'un parent (F03 / CA10).
 */
class GetArrivalStatusAction extends BaseAction
{
    public function __construct(
        private readonly ArrivalRepositoryInterface $arrivalRepository
    ) {}

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    public function handle(array $data): array
    {
        /** @var User $user */
        $user = $data['user'];
        /** @var School $school */
        $school = $data['school'];
        $schoolId = (string) $school->id;

        // Isolation multi-tenant stricte (ADR 0005)
        if ($user->school_id !== $schoolId) {
            abort(404, 'École introuvable.');
        }

        $now = Carbon::now('Africa/Casablanca');

        $latestArrival = $this->arrivalRepository->findLatestTodayForUserAndSchool((string) $user->id, $schoolId, $now);

        if (! $latestArrival) {
            return [
                'arrival' => null,
                'pickup_requests' => [],
                'has_active_cycle' => false,
            ];
        }

        $pickupRequests = $latestArrival->pickupRequests;

        // Un cycle est actif si au moins une demande aujourd'hui est en cours (non-terminale)
        // Les statuts terminaux sont : handed_over, cancelled, expired
        $hasActiveCycle = $pickupRequests->isNotEmpty() && $pickupRequests->contains(function (PickupRequest $pr) {
            return ! in_array($pr->status, [
                PickupRequest::STATUS_HANDED_OVER,
                PickupRequest::STATUS_CANCELLED,
                PickupRequest::STATUS_EXPIRED,
            ], true);
        });

        return [
            'arrival' => $latestArrival,
            'pickup_requests' => $pickupRequests,
            'has_active_cycle' => $hasActiveCycle,
        ];
    }
}
