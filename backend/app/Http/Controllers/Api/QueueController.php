<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\BaseController;
use App\Models\School;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur de la file d'attente tablette — F02 : Tablette d'accueil.
 *
 * SQUELETTE MINIMAL — Toutes les méthodes retournent HTTP 501 Not Implemented.
 * Aucune logique métier n'est codée ici (Étape 4 TDD — tests rouges).
 * L'implémentation sera effectuée à l'Étape 5 (TDD vert), CA par CA.
 *
 * Chaîne cible : Request → Controller → Action → Service → Repository → Model → DB
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
     *
     * SQUELETTE — retourne 501.
     */
    public function index(Request $request, School $school): JsonResponse
    {
        $user = $request->user();

        if ($user && (string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $this->authorize('viewQueue', $school);

        return response()->json([], 200);
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
