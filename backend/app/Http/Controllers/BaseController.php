<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;

/**
 * Contrôleur de base abstrait — API pure JSON.
 *
 * Aucune logique métier dans les contrôleurs (ADR 0002).
 * Les contrôleurs injectent les Actions et transmettent
 * les FormRequests validées.
 *
 * Réponses toujours en JSON, jamais en HTML.
 * Violation school_id → 404, jamais 403 (ADR 0005).
 *
 * Usage :
 *   class ArrivalController extends BaseController
 *   {
 *       public function store(ArrivalRequest $request, SignalArrivalAction $action)
 *       {
 *           return $this->success($action->handle($request->validated()), 201);
 *       }
 *   }
 */
abstract class BaseController extends Controller
{
    use AuthorizesRequests;

    /**
     * Réponse JSON de succès.
     */
    protected function success(mixed $data, int $code = 200): JsonResponse
    {
        return response()->json([
            'data' => $data,
        ], $code);
    }

    /**
     * Réponse JSON d'erreur.
     */
    protected function error(string $message, int $code): JsonResponse
    {
        return response()->json([
            'message' => $message,
        ], $code);
    }

    /**
     * Réponse 404 — utilisée pour les violations school_id.
     *
     * On retourne TOUJOURS 404 (jamais 403) pour empêcher
     * l'énumération de données inter-écoles (ADR 0005).
     */
    protected function notFound(): JsonResponse
    {
        return response()->json([
            'message' => 'Not Found',
        ], 404);
    }
}
