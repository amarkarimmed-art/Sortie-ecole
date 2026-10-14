<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Queue\ListActiveQueueAction;
use App\Http\Controllers\BaseController;
use App\Models\PickupRequest;
use App\Models\School;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

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
    ): JsonResponse {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('viewQueue', $school);

        $requests = $action->handle($school);

        $items = $requests->map(function (PickupRequest $req) {
            return [
                'id' => (string) $req->id,
                'child_id' => (string) $req->child_id,
                'child_name' => $req->child->first_name.' '.$req->child->last_name,
                'class_name' => $req->child->class_name,
                'status' => $req->status,
                'waiting_zone' => null,
                'photo_url' => $req->child->photo_path
                    ? rescue(fn () => Storage::disk('minio')->temporaryUrl($req->child->photo_path, now()->addMinutes(5)), null, false)
                    : null,
                'created_at' => $req->created_at->toIso8601String(),
            ];
        });

        return response()->json($items->values()->all(), 200);
    }

    /**
     * Valider la remise d'un enfant (F02 — CA4).
     *
     * POST /v1/schools/{school}/pickup-requests/{pickupRequest}/handover
     *
     * Rôles autorisés : concierge, director.
     * Exige l'en-tête Idempotency-Key (UUIDv4).
     * Transition vers handed_over depuis tout statut actif.
     * Écrit dans handover_logs (append-only).
     *
     * SQUELETTE — retourne 501.
     */
    public function handover(Request $request, School $school, string $requestId): JsonResponse
    {
        // TODO(F02-CA4): Implémenter HandoverAction
        return response()->json(['message' => 'Non implémenté.'], 501);
    }

    /**
     * Valider manuellement la présence d'un parent hors rayon (F02 — CA4 — pending_agent_confirmation).
     *
     * POST /v1/schools/{school}/pickup-requests/{pickupRequest}/confirm-presence
     *
     * Transition : pending_agent_confirmation → requested.
     * Rôles autorisés : concierge, director.
     *
     * SQUELETTE — retourne 501.
     */
    public function confirmPresence(Request $request, School $school, string $requestId): JsonResponse
    {
        // TODO(F02-CA4): Implémenter ConfirmPresenceAction
        return response()->json(['message' => 'Non implémenté.'], 501);
    }
}
