<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Models\Arrival;
use App\Repositories\Contracts\ArrivalRepositoryInterface;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

class ArrivalRepository extends BaseRepository implements ArrivalRepositoryInterface
{
    protected function getModel(): string
    {
        return Arrival::class;
    }

    /**
     * {@inheritDoc}
     */
    public function findLatestForUserAndSchool(string $userId, string $schoolId): ?Model
    {
        return $this->model->newQuery()
            ->where('user_id', $userId)
            ->where('school_id', $schoolId)
            ->latest()
            ->first();
    }

    /**
     * {@inheritDoc}
     */
    public function findLatestTodayForUserAndSchool(string $userId, string $schoolId, ?Carbon $now = null): ?Model
    {
        $now = $now ?? Carbon::now('Africa/Casablanca');

        return $this->model->newQuery()
            ->where('user_id', $userId)
            ->where('school_id', $schoolId)
            ->whereBetween('created_at', [$now->copy()->startOfDay(), $now->copy()->endOfDay()])
            ->with(['pickupRequests.child'])
            ->latest()
            ->first();
    }

    /**
     * {@inheritDoc}
     */
    public function findByIdempotencyKeyAndSchool(string $idempotencyKey, string $schoolId): ?Model
    {
        // Justifié : school_id explicite passé en clause WHERE, garantissant l'absence de fuite inter-écoles.
        return $this->model->newQuery()->withoutGlobalScopes()
            ->where('school_id', $schoolId)
            ->where('idempotency_key', $idempotencyKey)
            ->first();
    }
}
