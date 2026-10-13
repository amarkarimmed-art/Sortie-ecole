<?php

declare(strict_types=1);

namespace App\Services\Sms;

use App\Contracts\SmsGatewayInterface;

/**
 * Driver SMS factice pour les tests Pest.
 *
 * Capture les SMS envoyés en mémoire pour permettre les assertions
 * dans les tests sans dépendre d'un service externe.
 *
 * Usage dans les tests :
 *   $stub = app(SmsGatewayInterface::class);
 *   expect($stub->getLastMessage())->toContain('123456');
 */
class StubSmsGateway implements SmsGatewayInterface
{
    /** @var array<int, array{phone: string, message: string}> */
    private array $messages = [];

    public function send(string $phone, string $message): void
    {
        $this->messages[] = ['phone' => $phone, 'message' => $message];
    }

    /**
     * @return array<int, array{phone: string, message: string}>
     */
    public function getSentMessages(): array
    {
        return $this->messages;
    }

    public function getLastMessage(): string
    {
        if (empty($this->messages)) {
            return '';
        }

        return end($this->messages)['message'];
    }

    public function getLastPhone(): string
    {
        if (empty($this->messages)) {
            return '';
        }

        return end($this->messages)['phone'];
    }

    public function reset(): void
    {
        $this->messages = [];
    }
}
