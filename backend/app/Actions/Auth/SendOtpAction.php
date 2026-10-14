<?php

declare(strict_types=1);

namespace App\Actions\Auth;

use App\Actions\BaseAction;
use App\Contracts\SmsGatewayInterface;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Action métier : Envoi d'un OTP SMS (F01 — CA1, CA2).
 *
 * Responsabilités :
 * - Trouver l'utilisateur par son numéro de téléphone (→ 404 si inconnu)
 * - Rate limiting : 3 tentatives / 10 minutes par numéro (R2)
 * - Générer un code OTP à 6 chiffres, TTL 5 minutes, stocké dans Redis
 * - Envoyer le SMS via SmsGatewayInterface (log en dev, Vonage en prod)
 *
 * Conformité ADR 0008 : le SMS ne contient que le code OTP, sans données perso.
 */
class SendOtpAction extends BaseAction
{
    /** Durée de vie du code OTP en secondes. */
    private const OTP_TTL_SECONDS = 300; // 5 minutes

    /** Nombre max de tentatives par fenêtre de rate limiting. */
    private const MAX_ATTEMPTS = 3;

    /** Fenêtre de rate limiting en minutes. */
    private const DECAY_MINUTES = 10;

    public function __construct(
        private readonly SmsGatewayInterface $smsGateway,
    ) {}

    /**
     * @param  array<string, mixed>  $data  ['phone' => string]
     * @return array<string, mixed>
     */
    public function handle(array $data): Model|array
    {
        $phone = (string) $data['phone'];

        // 1. Rate limiting par numéro de téléphone (R2)
        $rateLimiterKey = 'otp:'.$phone;

        if (RateLimiter::tooManyAttempts($rateLimiterKey, self::MAX_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($rateLimiterKey);
            abort(429, "Trop de tentatives. Réessayez dans {$seconds} secondes.");
        }

        // 2. Trouver l'utilisateur — 404 si inconnu (CA2)
        // Note : On retourne 404 (et non 422) pour éviter l'énumération de numéros.
        $user = User::where('phone', $phone)->first();

        if (! $user) {
            // Incrémenter quand même le rate limiter pour éviter l'énumération par timing
            RateLimiter::hit($rateLimiterKey, self::DECAY_MINUTES * 60);
            abort(404, 'Utilisateur introuvable.');
        }

        // 3. Incrémenter le compteur de rate limiting
        RateLimiter::hit($rateLimiterKey, self::DECAY_MINUTES * 60);

        // 4. Générer l'OTP à 6 chiffres et le stocker dans Redis
        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $cacheKey = 'otp:code:'.$phone;

        Cache::put($cacheKey, $otp, self::OTP_TTL_SECONDS);

        // 5. Envoyer le SMS (texte générique — ADR 0008 : zéro donnée perso)
        $this->smsGateway->send(
            $phone,
            "Votre code de connexion Sortie d'école : {$otp}. Valable 5 minutes."
        );

        return ['message' => 'Code envoyé par SMS.'];
    }
}
