<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Arrival\GetArrivalStatusAction;
use App\Actions\Arrival\SignalArrivalAction;
use App\Events\ParentApproachingEvent;
use App\Http\Controllers\BaseController;
use App\Http\Requests\EvaluateLocationRequest;
use App\Http\Requests\SignalArrivalRequest;
use App\Models\School;
use App\Services\Geo\HaversineService;
use App\Services\Schedule\PickupScheduleService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur d'API pour les arrivées, la proximité GPS et le statut des horaires (F03).
 */
class ArrivalController extends BaseController
{
    /**
     * Obtenir le statut courant des horaires de l'école (F03 / Loi 09-08).
     */
    public function scheduleStatus(
        Request $request,
        School $school,
        PickupScheduleService $scheduleService
    ): JsonResponse {
        $user = $request->user();

        if (! $user || (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $status = $scheduleService->getCurrentStatus($school);

        return response()->json($status, 200);
    }

    /**
     * Évaluer la position GPS du parent en premier plan pendant les horaires de sortie.
     */
    public function evaluateLocation(
        EvaluateLocationRequest $request,
        School $school,
        HaversineService $haversine,
        PickupScheduleService $scheduleService
    ): JsonResponse {
        $user = $request->user();
        $schoolId = (string) $school->id;

        // 1. Isolation multi-école stricte
        if (! $user || (string) $user->school_id !== $schoolId) {
            abort(404, 'École introuvable.');
        }

        // 2. Vérification des horaires (refus si fermé)
        $now = Carbon::now('Africa/Casablanca');
        $scheduleStatus = $scheduleService->getCurrentStatus($school, $now);

        if (! $scheduleStatus['is_open']) {
            $msg = ! empty($scheduleStatus['next_opening_at'])
                ? "La sortie commence à {$scheduleStatus['next_opening_at']}"
                : ($scheduleStatus['message_fr'] ?: "Sortie fermée");
            abort(422, $msg);
        }

        // 3. Vérification de la précision GPS (accuracy <= 50m)
        $accuracy = $request->input('accuracy_meters') ?? $request->input('accuracy');
        if ($accuracy !== null && (float) $accuracy > 50.0) {
            abort(422, 'Précision GPS insuffisante, veuillez réessayer.');
        }

        // 4. Vérification de l'âge de la mesure (captured_at <= 60s)
        $capturedAt = $request->input('captured_at') ?? $request->input('timestamp');
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

        // 5. Calcul de distance Haversine
        $distanceMeters = 0;
        if ($school->gate_latitude !== null && $school->gate_longitude !== null) {
            $cLat = (float) ($request->input('pos_lat') ?? $request->input('lat') ?? 0);
            $cLng = (float) ($request->input('pos_lng') ?? $request->input('lng') ?? 0);
            $distanceMeters = $haversine->calculateDistance(
                $cLat,
                $cLng,
                (float) $school->gate_latitude,
                (float) $school->gate_longitude
            );
        }

        $radius = (int) ($school->perimeter_radius ?? 50);
        $proximityState = $haversine->evaluateProximity($distanceMeters, $radius);

        // 6. Diffusion Reverb si 'approaching' ou 'in_perimeter' (en RAM uniquement !)
        if (in_array($proximityState, ['approaching', 'in_perimeter'], true)) {
            $children = $user->children()->get()->map(function ($child) {
                return [
                    'id' => $child->id,
                    'first_name' => $child->first_name,
                    'last_name' => $child->last_name,
                    'class_name' => $child->class_name,
                ];
            })->all();

            try {
                broadcast(new ParentApproachingEvent(
                    $schoolId,
                    (string) $user->id,
                    (string) $user->name,
                    $children,
                    $distanceMeters,
                    $proximityState,
                    $now->toIso8601String()
                ))->toOthers();
            } catch (\Throwable) {
                // Ignore broadcast failure
            }
        }

        // 7. Messages clairs bilingues
        $messageFr = match ($proximityState) {
            'in_perimeter' => "Vous êtes dans le périmètre de l'école.",
            'approaching' => "Vous êtes à {$distanceMeters} m, rapprochez-vous (limite : {$radius} m).",
            default => "Vous êtes hors de la zone ({$distanceMeters} m).",
        };

        $messageAr = match ($proximityState) {
            'in_perimeter' => "أنت داخل نطاق المدرسة.",
            'approaching' => "أنت على بعد {$distanceMeters} م، يرجى الاقتراب (الحد : {$radius} م).",
            default => "أنت خارج نطاق المدرسة ({$distanceMeters} م).",
        };

        return response()->json([
            'proximity_state' => $proximityState,
            'distance_meters' => $distanceMeters,
            'perimeter_radius' => $radius,
            'can_signal_arrival' => ($proximityState === 'in_perimeter'),
            'schedule' => $scheduleStatus,
            'message_fr' => $messageFr,
            'message_ar' => $messageAr,
        ], 200);
    }

    /**
     * Signaler une arrivée parent (F03).
     */
    public function store(
        SignalArrivalRequest $request,
        School $school,
        SignalArrivalAction $action
    ): JsonResponse {
        $validated = $request->validated();
        $validated['user'] = $request->user();
        $validated['school'] = $school;
        $validated['idempotency_key'] = $request->header('Idempotency-Key');

        $arrival = $action->handle($validated);

        return response()->json($arrival, 201);
    }

    /**
     * Consulter le statut de l'arrivée courante (CA10).
     */
    public function status(
        Request $request,
        School $school,
        GetArrivalStatusAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $result = $action->handle([
            'user' => $user,
            'school' => $school,
        ]);

        return response()->json($result, 200);
    }
}
