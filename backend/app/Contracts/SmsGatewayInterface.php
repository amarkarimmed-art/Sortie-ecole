<?php

declare(strict_types=1);

namespace App\Contracts;

/**
 * Contrat d'envoi de SMS — Sortie d'école.
 *
 * Drivers disponibles (liés dans AppServiceProvider) :
 *   - LogSmsGateway   : SMS_DRIVER=log  → écrit dans storage/logs/laravel.log
 *   - VonageSmsGateway: SMS_DRIVER=vonage → Vonage / Twilio en production
 *
 * Conformité ADR 0008 : aucun nom, photo ou classe ne transite.
 * Le payload SMS ne contient que le code OTP et un texte générique.
 */
interface SmsGatewayInterface
{
    /**
     * Envoyer un SMS.
     *
     * @param  string  $phone    Numéro international (ex: +212612345678)
     * @param  string  $message  Texte du message (générique, sans données perso)
     */
    public function send(string $phone, string $message): void;
}
