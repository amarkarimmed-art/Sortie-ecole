<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Auth\SendOtpAction;
use App\Actions\Auth\VerifyOtpAction;
use App\Http\Controllers\BaseController;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use Illuminate\Http\JsonResponse;

/**
 * Contrôleur d'authentification SMS (F01).
 *
 * Mince et sans logique métier (ADR 0002).
 * Délègue à SendOtpAction et VerifyOtpAction.
 *
 * Routes :
 *   POST /api/v1/auth/login   → demander un code OTP
 *   POST /api/v1/auth/verify  → vérifier le code et obtenir un token Sanctum
 */
class AuthController extends BaseController
{
    /**
     * Demander un code OTP par SMS (CA1, CA2).
     */
    public function login(LoginRequest $request, SendOtpAction $action): JsonResponse
    {
        $result = $action->handle($request->validated());

        return response()->json($result, 200);
    }

    /**
     * Vérifier le code OTP et émettre un token Sanctum (CA3, CA4).
     */
    public function verify(VerifyOtpRequest $request, VerifyOtpAction $action): JsonResponse
    {
        $result = $action->handle($request->validated());

        return response()->json($result, 200);
    }
}
