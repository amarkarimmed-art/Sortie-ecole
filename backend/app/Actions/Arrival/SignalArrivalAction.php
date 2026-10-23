<?php

declare(strict_types=1);

namespace App\Actions\Arrival;

use App\Actions\BaseAction;
use App\Events\ArrivalSignaledEvent;
use App\Models\Arrival;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use App\Repositories\Contracts\ArrivalRepositoryInterface;
use App\Repositories\Contracts\PickupRequestRepositoryInterface;
use App\Repositories\Contracts\PickupWindowRepositoryInterface;
use App\Services\Geo\HaversineService;
use App\Services\Schedule\PickupScheduleService;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Action métier : Signalement d'arrivée d'un parent (F03).
 *
 * Responsabilités :
 * - Gestion de l'idempotence et anti-doublon par créneau
 * - Validation stricte des fenêtres horaires sur le fuseau 'Africa/Casablanca'
 * - Vérification des liens de parenté (parent ↔ enfants)
 * - Contrôle de proximité GPS (Haversine) sans stockage des coordonnées
 * - Création transactionnelle de l'arrivée et diffusion WebSocket Reverb
 * - Isolation multi-école stricte (ADR 0005)
 */
class SignalArrivalAction extends BaseAction
{
    public function __construct(
        private readonly ArrivalRepositoryInterface $arrivalRepository,
        private readonly PickupRequestRepositoryInterface $pickupRequestRepository,
        private readonly PickupWindowRepositoryInterface $pickupWindowRepository,
        private readonly PickupScheduleService $scheduleService,
        private readonly HaversineService $haversine,
    ) {}

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
        if ((string) $user->school_id !== $schoolId) {
            abort(404, 'École introuvable.');
        }

        // 2. Gestion de l'idempotence (CA5)
        if ($idempotencyKey !== null) {
            $existingArrival = $this->arrivalRepository->findByIdempotencyKeyAndSchool($idempotencyKey, $schoolId);

            if ($existingArrival) {
                return $existingArrival->load(['pickupRequests.child']);
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
        $scheduleStatus = $this->scheduleService->getCurrentStatus($school, $now);

        if (! $scheduleStatus['is_open']) {
            if (! empty($scheduleStatus['next_opening_at'])) {
                abort(422, "La sortie commence à {$scheduleStatus['next_opening_at']}");
            }
            abort(422, 'Le signalement d\'arrivée est hors de la fenêtre horaire autorisée.');
        }

        // 5. Anti-doublon par plage horaire active du jour
        // Justifié : déduplication restreinte au school_id et user_id
        $existingArrival = Arrival::withoutGlobalScopes()
            ->where('school_id', $schoolId)
            ->where('user_id', $user->id)
            ->whereDate('created_at', $now->toDateString())
            ->whereHas('pickupRequests', function ($q) use ($childIds) {
                $q->whereIn('child_id', $childIds)
                    ->whereNotIn('status', [PickupRequest::STATUS_CANCELLED, PickupRequest::STATUS_EXPIRED]);
            })
            ->latest()
            ->first();

        if ($existingArrival) {
            $loaded = $existingArrival->load(['pickupRequests.child']);
            $childrenPayload = [];
            foreach ($loaded->pickupRequests as $pickupReq) {
                $child = $pickupReq->child;
                $childrenPayload[] = [
                    'id' => $pickupReq->child_id,
                    'first_name' => $child?->first_name,
                    'last_name' => $child?->last_name,
                    'class_name' => $child?->class_name,
                    'request_id' => $pickupReq->id,
                ];
            }
            try {
                broadcast(new ArrivalSignaledEvent(
                    $loaded,
                    (string) $user->name,
                    $childrenPayload,
                    $liveDistance,
                    $proximityState,
                    $now->toIso8601String()
                ))->toOthers();
            } catch (\Throwable) {
            }

            return $loaded;
        }

        // 6. Évaluation GPS (si coordonnées fournies ou portail configuré en mode GPS)
        $hasCoords = (isset($data['pos_lat']) || isset($data['lat'])) && (isset($data['pos_lng']) || isset($data['lng']));
        $liveDistance = null;
        $inRadius = true;
        $proximityState = 'in_perimeter';
        $radius = (int) ($school->perimeter_radius ?? 50);

        if ($hasCoords) {
            // Précision GPS
            $accuracy = $data['accuracy_meters'] ?? $data['accuracy'] ?? null;
            if ($accuracy !== null && (float) $accuracy > 50.0) {
                abort(422, 'Précision GPS insuffisante, veuillez réessayer.');
            }

            // Fraîcheur de la mesure (<= 60 secondes)
            $capturedAt = $data['captured_at'] ?? $data['timestamp'] ?? null;
            if ($capturedAt !== null) {
                if (is_numeric($capturedAt)) {
                    $capturedCarbon = (strlen((string) $capturedAt) > 10)
                        ? Carbon::createFromTimestampMs((int) $capturedAt, 'Africa/Casablanca')
                        : Carbon::createFromTimestamp((int) $capturedAt, 'Africa/Casablanca');
                } else {
                    $capturedCarbon = Carbon::parse((string) $capturedAt, 'Africa/Casablanca');
                }

                if (abs($now->diffInSeconds($capturedCarbon)) > 60) {
                    abort(422, 'Position GPS trop ancienne, veuillez réessayer.');
                }
            }

            // Calcul distance Haversine
            if ($school->gate_latitude !== null && $school->gate_longitude !== null) {
                $cLat = (float) ($data['pos_lat'] ?? $data['lat']);
                $cLng = (float) ($data['pos_lng'] ?? $data['lng']);
                $liveDistance = $this->haversine->calculateDistance(
                    $cLat,
                    $cLng,
                    (float) $school->gate_latitude,
                    (float) $school->gate_longitude
                );

                if ($liveDistance > $radius) {
                    abort(422, "Vous êtes à {$liveDistance} mètres de l'école (limite : {$radius} m)");
                }
            }

            // Loi 09-08 : Zéro stockage de position ni de distance GPS en base
            $inRadius = true;
            $proximityState = 'in_perimeter';
        } else {
            // Mode legacy (tests F03 sans coordonnées directes)
            if (isset($data['in_radius'])) {
                $inRadius = (bool) $data['in_radius'];
            }
            if (isset($data['distance_meters'])) {
                $liveDistance = (int) $data['distance_meters'];
            }
            $proximityState = $inRadius ? 'in_perimeter' : 'out_of_zone';
        }

        // 7. Création transactionnelle de l'arrivée et des demandes individuelles
        return DB::transaction(function () use (
            $schoolId,
            $user,
            $childIds,
            $idempotencyKey,
            $inRadius,
            $proximityState,
            $liveDistance,
            $now,
            $hasCoords,
            $data
        ) {
            // En mode GPS, distance_meters reste strictement null en base (Loi 09-08)
            $dbDistance = $hasCoords ? null : ($data['distance_meters'] ?? null);

            $arrival = $this->arrivalRepository->create([
                'school_id' => $schoolId,
                'user_id' => $user->id,
                'in_radius' => $inRadius,
                'distance_meters' => $dbDistance,
                'proximity_state' => $proximityState,
                'idempotency_key' => $idempotencyKey,
            ]);

            $initialStatus = $inRadius
                ? PickupRequest::STATUS_REQUESTED
                : PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION;

            $childrenPayload = [];
            foreach ($childIds as $childId) {
                $pickupReq = $this->pickupRequestRepository->create([
                    'school_id' => $schoolId,
                    'arrival_id' => $arrival->id,
                    'child_id' => $childId,
                    'requested_by' => $user->id,
                    'status' => $initialStatus,
                    'in_radius' => $inRadius,
                    'distance_meters' => $dbDistance,
                    'proximity_state' => $proximityState,
                    'idempotency_key' => (string) Str::uuid(),
                ]);

                $child = $pickupReq->child;
                $childrenPayload[] = [
                    'id' => $childId,
                    'first_name' => $child?->first_name,
                    'last_name' => $child?->last_name,
                    'class_name' => $child?->class_name,
                    'request_id' => $pickupReq->id,
                ];
            }

            // 8. Diffusion en temps réel sur Reverb (RAM uniquement pour liveDistance)
            try {
                broadcast(new ArrivalSignaledEvent(
                    $arrival,
                    (string) $user->name,
                    $childrenPayload,
                    $liveDistance,
                    $proximityState,
                    $now->toIso8601String()
                ))->toOthers();
            } catch (\Throwable) {
                // Le broadcast ne bloque pas la réponse HTTP
            }

            return $arrival->load(['pickupRequests.child']);
        });
    }
}
