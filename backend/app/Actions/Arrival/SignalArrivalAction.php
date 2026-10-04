<?php

declare(strict_types=1);

namespace App\Actions\Arrival;

use App\Actions\BaseAction;
use App\Models\Arrival;
use App\Models\PickupRequest;
use App\Models\PickupWindow;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Action métier : Signalement d'arrivée d'un parent (F03).
 *
 * Responsabilités :
 * - Gestion de l'idempotence (en-tête Idempotency-Key)
 * - Validation stricte des fenêtres horaires sur le fuseau 'Africa/Casablanca'
 * - Vérification des liens de parenté (parent ↔ enfants)
 * - Création transactionnelle de l'arrivée et des demandes individuelles
 * - Isolation multi-école stricte (ADR 0005)
 */
class SignalArrivalAction extends BaseAction
{
    /**
     * @param  array<string, mixed>  $data
     * @return Model|array<string, mixed>
     */
    public function handle(array $data): Model|array
    {
        /** @var User $user */
        $user = $data['user'];
        /** @var School $school */
        $school = $data['school'];
        $schoolId = (string) $school->id;
        $childIds = (array) $data['child_ids'];
        $idempotencyKey = isset($data['idempotency_key']) && ! empty($data['idempotency_key'])
            ? (string) $data['idempotency_key']
            : null;

        // 1. Isolation multi-tenant (ADR 0005)
        if ($user->school_id !== $schoolId) {
            abort(404, 'École introuvable.');
        }

        // 2. Gestion de l'idempotence (CA5)
        if ($idempotencyKey !== null) {
            $existingArrival = Arrival::withoutGlobalScopes()
                ->where('school_id', $schoolId)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($existingArrival) {
                return $existingArrival->load('pickupRequests');
            }
        }

        // 3. Vérification des droits parentaux (CA7)
        $associatedCount = $user->children()
            ->whereIn('children.id', $childIds)
            ->count();

        if ($associatedCount !== count($childIds)) {
            abort(422, 'Un ou plusieurs élèves ne sont pas rattachés à ce tuteur.');
        }

        // 4. Contrôle de la fenêtre horaire (fuseau Africa/Casablanca, CA2, CA3)
        $now = Carbon::now('Africa/Casablanca');
        $dayOfWeek = $now->dayOfWeekIso; // 1 = Lundi, ..., 7 = Dimanche
        $currentTime = $now->format('H:i:s');

        $windows = PickupWindow::withoutGlobalScopes()
            ->where('school_id', $schoolId)
            ->where('day_of_week', $dayOfWeek)
            ->get();

        $isInWindow = $windows->contains(function (PickupWindow $window) use ($currentTime) {
            return $currentTime >= $window->start_time && $currentTime <= $window->end_time;
        });

        if (! $isInWindow) {
            abort(422, 'Le signalement d\'arrivée est hors de la fenêtre horaire autorisée.');
        }

        // 5. Création transactionnelle de l'arrivée et des demandes de sortie (CA1, CA4, CA6)
        return DB::transaction(function () use ($schoolId, $user, $data, $childIds, $idempotencyKey) {
            $inRadius = (bool) $data['in_radius'];
            $distanceMeters = isset($data['distance_meters']) && $data['distance_meters'] !== null
                ? (int) $data['distance_meters']
                : null;

            $arrival = Arrival::create([
                'school_id' => $schoolId,
                'user_id' => $user->id,
                'in_radius' => $inRadius,
                'distance_meters' => $distanceMeters,
                'idempotency_key' => $idempotencyKey,
            ]);

            $initialStatus = $inRadius
                ? PickupRequest::STATUS_REQUESTED
                : PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION;

            foreach ($childIds as $childId) {
                PickupRequest::create([
                    'school_id' => $schoolId,
                    'arrival_id' => $arrival->id,
                    'child_id' => $childId,
                    'requested_by' => $user->id,
                    'status' => $initialStatus,
                    'in_radius' => $inRadius,
                    'distance_meters' => $distanceMeters,
                    'idempotency_key' => (string) Str::uuid(),
                ]);
            }

            return $arrival->load('pickupRequests');
        });
    }
}
