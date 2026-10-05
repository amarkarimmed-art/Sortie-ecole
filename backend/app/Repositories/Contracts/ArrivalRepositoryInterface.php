<?php

declare(strict_types=1);

namespace App\Repositories\Contracts;

use Illuminate\Database\Eloquent\Model;

interface ArrivalRepositoryInterface extends RepositoryInterface
{
    /**
     * Trouver la dernière arrivée d'un parent pour une école donnée.
     */
    public function findLatestForUserAndSchool(string $userId, string $schoolId): ?Model;

    /**
     * Trouver une arrivée via sa clé d'idempotence.
     */
    public function findByIdempotencyKeyAndSchool(string $idempotencyKey, string $schoolId): ?Model;
}
