<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Queue\CallClassAction;
use App\Actions\Queue\ConfirmPresenceAction;
use App\Actions\Queue\HandoverAction;
use App\Actions\Queue\ListActiveQueueAction;
use App\Exceptions\Queue\HandoverDejaEnregistreException;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Http\Controllers\BaseController;
use App\Http\Resources\QueueItemResource;
use App\Models\PickupRequest;
use App\Models\School;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Validator;

/**
 * Contrôleur de la file d'attente tablette — F02 : Tablette d'accueil.
 *
 * Mince et sans logique métier (ADR 0002).
 * Délègue aux actions dédiées.
 */
class QueueController extends BaseController
{
    /**
     * Récupérer la file d'attente du jour (F02 — CA1, CA2, CA3).
     *
     * GET /v1/schools/{school}/queue
     *
     * Rôles autorisés : concierge, director.
     * Filtrage : statuts actifs du jour (00:00:00 Africa/Casablanca).
     * Tri : chronologique ascendant (created_at).
     */
    public function index(
        Request $request,
        School $school,
        ListActiveQueueAction $action
    ): AnonymousResourceCollection {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('viewQueue', $school);

        $requests = $action->handle($school);

        return QueueItemResource::collection($requests);
    }

    /**
     * Valider la remise d'un enfant (F02 — CA4).
     *
     * POST /v1/schools/{school}/pickup-requests/{requestId}/handover
     *
     * Rôles autorisés : concierge, director.
     * Exige l'en-tête Idempotency-Key (UUIDv4).
     * Transition vers handed_over depuis tout statut actif (B2).
     * Écrit dans handover_logs (append-only).
     */
    public function handover(
        Request $request,
        School $school,
        string $requestId,
        HandoverAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('handover', $school);

        // Validation Idempotency-Key obligatoire
        $idempotencyKey = $request->header('Idempotency-Key');
        if (empty($idempotencyKey)) {
            return response()->json([
                'message' => "L'en-tête Idempotency-Key est obligatoire.",
                'errors' => [
                    'idempotency_key' => ["L'en-tête Idempotency-Key est obligatoire."],
                ],
            ], 422);
        }

        $validator = Validator::make($request->all(), [
            'collector_type' => ['required', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Données invalides.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $pickupRequest = PickupRequest::where('school_id', $school->id)
            ->where('id', $requestId)
            ->first();

        if (! $pickupRequest) {
            abort(404, 'Demande introuvable.');
        }

        $collectorType = (string) $request->input('collector_type');
        $collectorId = $request->input('parent_user_id') ?? $request->input('authorized_person_id');

        try {
            $log = $action->handle(
                request: $pickupRequest,
                agent: $user,
                idempotencyKey: $idempotencyKey,
                collectorType: $collectorType,
                collectorId: $collectorId ? (string) $collectorId : null
            );

            return response()->json($log, 201);
        } catch (HandoverDejaEnregistreException $e) {
            return response()->json($e->getExistingLog(), 409);
        } catch (HandoverImpossibleException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 422);
        }
    }

    /**
     * Valider manuellement la présence d'un parent hors rayon (F02 — CA4 — pending_agent_confirmation).
     *
     * POST /v1/schools/{school}/pickup-requests/{requestId}/confirm-presence
     *
     * Transition : pending_agent_confirmation → requested.
     * Rôles autorisés : concierge, director.
     */
    public function confirmPresence(
        Request $request,
        School $school,
        string $requestId,
        ConfirmPresenceAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('confirmPresence', $school);

        $pickupRequest = PickupRequest::where('school_id', $school->id)
            ->where('id', $requestId)
            ->first();

        if (! $pickupRequest) {
            abort(404, 'Demande introuvable.');
        }

        try {
            $updated = $action->handle($pickupRequest);

            return response()->json([
                'id' => (string) $updated->id,
                'status' => $updated->status,
                'message' => 'Présence confirmée avec succès.',
            ], 200);
        } catch (HandoverImpossibleException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 422);
        }
    }

    /**
     * Appeler une classe pour une demande (F04 — CA1, CA2, CA3, CA10).
     *
     * POST /v1/schools/{school}/pickup-requests/{requestId}/call
     *
     * Rôles autorisés : concierge, director.
     * Exige l'en-tête Idempotency-Key (UUIDv4).
     * Transition vers class_notified.
     */
    public function callClass(
        Request $request,
        School $school,
        string $requestId,
        CallClassAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('call', $school);

        $idempotencyKey = $request->header('Idempotency-Key');
        if (empty($idempotencyKey)) {
            return response()->json([
                'message' => "L'en-tête Idempotency-Key est obligatoire.",
                'errors' => [
                    'idempotency_key' => ["L'en-tête Idempotency-Key est obligatoire."],
                ],
            ], 422);
        }

        $pickupRequest = PickupRequest::where('school_id', $school->id)
            ->where('id', $requestId)
            ->first();

        if (! $pickupRequest) {
            abort(404, 'Demande introuvable.');
        }

        try {
            $updated = $action->handle($pickupRequest, $user, (string) $idempotencyKey);

            return response()->json([
                'id' => (string) $updated->id,
                'status' => $updated->status,
                'updated_at' => $updated->updated_at?->toISOString() ?? Carbon::now('Africa/Casablanca')->toISOString(),
            ], 200);
        } catch (HandoverImpossibleException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 422);
        }
    }
}
