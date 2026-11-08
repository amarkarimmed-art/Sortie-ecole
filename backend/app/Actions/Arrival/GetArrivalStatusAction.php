<?php

declare(strict_types=1);

namespace App\Actions\Arrival;

use App\Actions\BaseAction;
use App\Models\Arrival;
use App\Models\School;
use App\Models\User;
use App\Repositories\Contracts\ArrivalRepositoryInterface;
use Carbon\Carbon;

/**
 * Action métier : Consultation du statut de l'arrivée courante d'un parent (F03 / CA10).
 *
 * Renvoie toutes les arrivées et demandes du jour (Africa/Casablanca), pas uniquement la dernière.
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

        // Bornes du jour en heure de Casablanca, converties en UTC
        $now = Carbon::now('Africa/Casablanca');
        $startOfDayCasa = $now->copy()->startOfDay()->utc();
        $endOfDayCasa = $now->copy()->endOfDay()->utc();

        // Justifié : toutes les arrivées du jour pour ce parent dans cette école
        $arrivals = Arrival::withoutGlobalScopes()
            ->where('school_id', $schoolId)
            ->where('user_id', $user->id)
            ->whereBetween('created_at', [$startOfDayCasa, $endOfDayCasa])
            ->with('pickupRequests.child')
            ->latest()
            ->get();

        // Rassembler toutes les demandes de toutes les arrivées du jour
        $allPickupRequests = $arrivals->flatMap(fn (Arrival $a) => $a->pickupRequests);

        return [
            'arrival' => $arrivals->first(),
            'arrivals' => $arrivals,
            'pickup_requests' => $allPickupRequests->values(),
        ];
    }
}
