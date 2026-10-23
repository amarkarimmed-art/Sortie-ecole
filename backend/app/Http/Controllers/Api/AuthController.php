<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Auth\LoginWithPasswordAction;
use App\Http\Controllers\BaseController;
use App\Models\School;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur d'authentification par Login + Mot de passe.
 *
 * Mince et sans logique métier (ADR 0002).
 * Délègue à LoginWithPasswordAction.
 *
 * Routes :
 *   POST /api/login  → Connexion avec login + mot de passe
 *   POST /api/logout → Révocation du token Sanctum
 *   GET  /api/me     → Profil de l'utilisateur connecté
 */
class AuthController extends BaseController
{
    /**
     * Connexion par login + mot de passe.
     */
    public function login(Request $request, LoginWithPasswordAction $action): JsonResponse
    {
        $validated = $request->validate([
            'login'    => ['required', 'string'],
            'password' => ['required', 'string'],
            'app_type' => ['nullable', 'string', 'in:parent,ecole,app_parent,app_ecole'],
        ]);

        $appType = $validated['app_type'] ?? $request->header('X-App-Type');

        $result = $action->handle([
            'login'    => $validated['login'],
            'password' => $validated['password'],
            'app_type' => $appType,
            'ip'       => $request->ip(),
        ]);

        return response()->json($result['response'], $result['status']);
    }

    /**
     * Révocation du token Sanctum courant.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'message' => 'Déconnexion réussie.',
        ], 200);
    }

    /**
     * Profil de l'utilisateur connecté pour reconnexion automatique.
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            return response()->json([
                'message' => 'Unauthenticated.',
            ], 401);
        }

        // Justifié : Récupération de l'école de l'utilisateur connecté sans global scope
        $school = School::withoutGlobalScopes()->find($user->school_id);

        if (! $school || $school->is_suspended) {
            return response()->json([
                'message' => "École suspendue, contactez l'administration.",
            ], 403);
        }

        return response()->json([
            'user' => LoginWithPasswordAction::formatUserPayload($user, $school),
        ], 200);
    }
}
