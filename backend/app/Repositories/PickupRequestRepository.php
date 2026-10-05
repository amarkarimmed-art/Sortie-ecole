<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Models\PickupRequest;
use App\Repositories\Contracts\PickupRequestRepositoryInterface;

class PickupRequestRepository extends BaseRepository implements PickupRequestRepositoryInterface
{
    /**
     * @return string
     */
    protected function getModel(): string
    {
        return PickupRequest::class;
    }
}
