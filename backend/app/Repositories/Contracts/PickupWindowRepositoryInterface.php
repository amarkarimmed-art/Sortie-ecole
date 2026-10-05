<?php

declare(strict_types=1);

namespace App\Repositories\Contracts;

use Illuminate\Support\Collection;

interface PickupWindowRepositoryInterface extends RepositoryInterface
{
    /**
     * Obtenir les fenêtres horaires pour une école et un jour donné.
     */
    public function getWindowsForSchoolAndDay(string $schoolId, int $dayOfWeek): Collection;
}
