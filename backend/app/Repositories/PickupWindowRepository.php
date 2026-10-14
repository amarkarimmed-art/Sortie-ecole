<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Models\PickupWindow;
use App\Repositories\Contracts\PickupWindowRepositoryInterface;
use Illuminate\Support\Collection;

class PickupWindowRepository extends BaseRepository implements PickupWindowRepositoryInterface
{
    protected function getModel(): string
    {
        return PickupWindow::class;
    }

    /**
     * {@inheritDoc}
     */
    public function getWindowsForSchoolAndDay(string $schoolId, int $dayOfWeek): Collection
    {
        return $this->model->newQuery()
            ->withoutGlobalScopes()
            ->where('school_id', $schoolId)
            ->where('day_of_week', $dayOfWeek)
            ->get();
    }
}
