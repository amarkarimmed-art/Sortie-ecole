<?php

declare(strict_types=1);

namespace App\Actions\Arrival;

use App\Actions\BaseAction;
use App\Models\School;
use App\Models\User;
use App\Repositories\Contracts\ArrivalRepositoryInterface;

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

        $latestArrival = $this->arrivalRepository->findLatestForUserAndSchool((string) $user->id, $schoolId);

        return [
            'arrival' => $latestArrival,
            'pickup_requests' => $latestArrival ? $latestArrival->pickupRequests : [],
        ];
    }
}
