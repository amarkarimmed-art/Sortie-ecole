<?php

declare(strict_types=1);

namespace App\Exceptions\Queue;

use Exception;

class IdempotencyConflictException extends Exception
{
    public function __construct(string $message = "La clé d'idempotence a déjà été utilisée avec un corps différent.")
    {
        parent::__construct($message);
    }
}
