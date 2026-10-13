<?php

declare(strict_types=1);

namespace App\Services\Sms;

use App\Contracts\SmsGatewayInterface;
use Illuminate\Support\Facades\Log;

/**
 * Driver SMS de développement et de test.
 *
 * En local (SMS_DRIVER=log), le message SMS est écrit dans
 * storage/logs/laravel.log à la place d'être transmis à une
 * passerelle réelle.
 *
 * Format du log :
 *   [SMS] TO=+212612345678 | MSG=Votre code OTP est : 123456
 */
class LogSmsGateway implements SmsGatewayInterface
{
    public function send(string $phone, string $message): void
    {
        Log::info('[SMS] TO=' . $phone . ' | MSG=' . $message);
    }
}
