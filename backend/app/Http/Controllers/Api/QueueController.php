<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Queue\CallClassAction;
use App\Actions\Queue\ConfirmPresenceAction;
use App\Actions\Queue\HandoverAction;
use App\Actions\Queue\ListActiveQueueAction;
use App\Actions\Queue\MarkDepartAction;
use App\Exceptions\Queue\HandoverDejaEnregistreException;
use App\Exceptions\Queue\HandoverImpossibleException;
use App\Exceptions\Queue\IdempotencyConflictException;
use App\Http\Controllers\BaseController;
use App\Http\Resources\QueueItemResource;
use App\Models\Arrival;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

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

        $requests = $action->handle($school, $user);

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
            'collector_type' => ['nullable', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Données invalides.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $pickupRequest = PickupRequest::withoutGlobalScopes()
            ->where('school_id', $school->id)
            ->where('id', $requestId)
            ->first();

        if (! $pickupRequest) {
            $today = Carbon::now('Africa/Casablanca')->toDateString();
            $pickupRequest = PickupRequest::withoutGlobalScopes()
                ->where('school_id', $school->id)
                ->whereDate('created_at', $today)
                ->where(function ($q) use ($requestId) {
                    $q->where('arrival_id', $requestId)
                        ->orWhere('child_id', $requestId)
                        ->orWhere('requested_by', $requestId);
                })
                ->whereNotIn('status', [PickupRequest::STATUS_CANCELLED, PickupRequest::STATUS_EXPIRED])
                ->latest('created_at')
                ->first();
        }

        if (! $pickupRequest) {
            abort(404, 'Demande introuvable.');
        }

        $collectorType = (string) ($request->input('collector_type') ?? 'parent');
        $collectorId = $request->input('parent_user_id') ?? $request->input('authorized_person_id') ?? $pickupRequest->requested_by;

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
            $response = $action->handle(
                $pickupRequest,
                $user,
                (string) $idempotencyKey,
                $request->except(['_method', '_token'])
            );

            return response()->json($response, 200);
        } catch (IdempotencyConflictException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 409);
        } catch (HandoverImpossibleException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 422);
        }
    }

    /**
     * Marquer le départ d'une demande de sortie (F04 — CA4, CA5, CA6, CA19).
     *
     * POST /v1/schools/{school}/pickup-requests/{requestId}/depart
     *
     * Rôles autorisés : surveillant, director.
     * Exige l'en-tête Idempotency-Key (UUIDv4).
     * Transition vers on_the_way depuis class_notified.
     */
    public function markDepart(
        Request $request,
        School $school,
        string $requestId,
        MarkDepartAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('depart', $school);

        $idempotencyKey = $request->header('Idempotency-Key');
        if (empty($idempotencyKey)) {
            return response()->json([
                'message' => "L'en-tête Idempotency-Key est obligatoire.",
                'errors' => [
                    'idempotency_key' => ["L'en-tête Idempotency-Key est obligatoire."],
                ],
            ], 422);
        }

        // 1. Cherche d'abord par PickupRequest::withoutGlobalScopes()->where('school_id', $school->id)->where('id', $requestId)->first().
        // Justifié : recherche de la demande par son id primaire sans restriction de scope global
        $pickupRequest = PickupRequest::withoutGlobalScopes()
            ->where('school_id', $school->id)
            ->where('id', $requestId)
            ->first();

        // 2. Si non trouvé par id, cherche la demande active du jour dans cette école par where('arrival_id', $requestId) OU where('child_id', $requestId) OU where('requested_by', $requestId) (latest('created_at')->first()).
        if (! $pickupRequest) {
            $today = Carbon::now('Africa/Casablanca')->toDateString();
            // Justifié : recherche de secours multi-clé par arrival_id, child_id ou requested_by
            $pickupRequest = PickupRequest::withoutGlobalScopes()
                ->where('school_id', $school->id)
                ->whereDate('created_at', $today)
                ->where(function ($q) use ($requestId) {
                    $q->where('arrival_id', $requestId)
                        ->orWhere('child_id', $requestId)
                        ->orWhere('requested_by', $requestId);
                })
                ->whereNotIn('status', [PickupRequest::STATUS_CANCELLED, PickupRequest::STATUS_EXPIRED])
                ->latest('created_at')
                ->first();
        }

        // 3. Si toujours non trouvé mais que $requestId correspond à un Child ou un User (parent) de cette école $school->id, crée à la volée la PickupRequest pour cet élève et marque-la directement en on_the_way !
        if (! $pickupRequest) {
            // Justifié : recherche d'un élève de l'école correspondant à requestId
            $child = Child::withoutGlobalScopes()
                ->where('school_id', $school->id)
                ->where('id', $requestId)
                ->first();

            $parentUser = null;
            if (! $child) {
                // Justifié : recherche d'un tuteur de l'école correspondant à requestId
                $parentUser = User::withoutGlobalScopes()
                    ->where('school_id', $school->id)
                    ->where('id', $requestId)
                    ->first();
                if ($parentUser) {
                    $child = $parentUser->children()->first();
                }
            } else {
                $parentUser = $child->parents()->first();
            }

            if ($child) {
                $today = Carbon::now('Africa/Casablanca')->toDateString();
                // Justifié : recherche de l'arrivée du jour pour la création à la volée
                $arrival = Arrival::withoutGlobalScopes()
                    ->where('school_id', $school->id)
                    ->when($parentUser, fn ($q) => $q->where('user_id', $parentUser->id))
                    ->whereDate('created_at', $today)
                    ->latest('created_at')
                    ->first();

                if (! $arrival && $parentUser) {
                    $arrival = Arrival::create([
                        'school_id' => $school->id,
                        'user_id' => $parentUser->id,
                        'in_radius' => true,
                        'proximity_state' => 'in_perimeter',
                        'idempotency_key' => (string) Str::uuid(),
                    ]);
                }

                $pickupRequest = PickupRequest::create([
                    'school_id' => $school->id,
                    'arrival_id' => $arrival?->id,
                    'child_id' => $child->id,
                    'requested_by' => $parentUser?->id ?? $user->id,
                    'status' => PickupRequest::STATUS_REQUESTED,
                    'in_radius' => true,
                    'proximity_state' => 'in_perimeter',
                    'idempotency_key' => (string) Str::uuid(),
                ]);
            }
        }

        if (! $pickupRequest) {
            abort(404, 'Demande introuvable.');
        }

        try {
            $response = $action->handle(
                $pickupRequest,
                $user,
                (string) $idempotencyKey,
                $request->except(['_method', '_token'])
            );

            return response()->json($response, 200);
        } catch (IdempotencyConflictException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 409);
        } catch (HandoverImpossibleException $e) {
            return response()->json([
                'message' => $e->getMessage(),
            ], 422);
        }
    }
}
