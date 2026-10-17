<?php

declare(strict_types=1);

namespace App\Actions\Auth;

use App\Actions\BaseAction;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Action métier : Vérification OTP et émission du token Sanctum (F01 — CA3, CA4).
 *
 * Responsabilités :
 * - Récupérer l'OTP depuis Redis
 * - Comparer avec le code soumis (→ 401 si invalide ou expiré)
 * - Invalider l'OTP après usage (one-time use)
 * - Émettre un token Sanctum associé à l'utilisateur
 * - Retourner le token + les informations de l'utilisateur (+ école — Q3 : mono-école)
 *
 * Q3 : Un seul établissement par token.
 * Conformité ADR 0005 : school_id est embarqué dans la réponse.
 */
class VerifyOtpAction extends BaseAction
{
    /**
     * @param  array<string, mixed>  $data  ['phone' => string, 'code' => string]
     * @return array<string, mixed>
     */
    public function handle(array $data): Model|array
    {
        $phone = (string) $data['phone'];
        $submittedCode = (string) $data['code'];

        // 1. Récupérer l'OTP depuis Redis
        $cacheKey = 'otp:code:'.$phone;
        $storedOtp = Cache::get($cacheKey);

        // 2. Vérifier la validité (→ 401 si expiré ou invalide — CA4)
        if ($storedOtp === null || $storedOtp !== $submittedCode) {
            abort(401, 'Code OTP invalide ou expiré.');
        }

        // 3. Invalider l'OTP immédiatement (usage unique)
        Cache::forget($cacheKey);

        // 4. Réinitialiser le rate limiter du numéro
        RateLimiter::clear('otp:'.$phone);

        // 5. Récupérer l'utilisateur
        $user = User::where('phone', $phone)->firstOrFail();

        // 6. Marquer le téléphone comme vérifié si ce n'est pas déjà fait
        if (! $user->phone_verified_at) {
            $user->phone_verified_at = now();
            $user->save();
        }

        // 7. Émettre le token Sanctum (CA3)
        $token = $user->createToken('mobile')->plainTextToken;

        // 8. Retourner token + user + école (Q3 : mono-école, school_id inclus) + enfants
        return [
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'phone' => $user->phone,
                'role' => $user->role,
                'locale' => $user->locale,
                'school_id' => $user->school_id,
                'children' => $user->children->map(fn ($child) => [
                    'id' => (string) $child->id,
                    'school_id' => (string) $child->school_id,
                    'first_name' => (string) $child->first_name,
                    'last_name' => (string) $child->last_name,
                    'class_name' => (string) $child->class_name,
                    'photo_url' => $child->photo_path,
                ])->values()->all(),
            ],
        ];
    }
}
