<?php

declare(strict_types=1);

namespace App\Exceptions\Queue;

use App\Models\HandoverLog;
use Exception;

class HandoverDejaEnregistreException extends Exception
{
    public function __construct(
        private readonly HandoverLog $existingLog,
        string $message = 'Cette remise a déjà été enregistrée.'
    ) {
        parent::__construct($message);
    }

    public function getExistingLog(): HandoverLog
    {
        return $this->existingLog;
    }
}
