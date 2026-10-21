<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\School;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class SuperAdminStatsOverview extends BaseWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $activeSchools = School::where('is_suspended', false)->count();
        $suspendedSchools = School::where('is_suspended', true)->count();
        $directorsCount = User::withoutGlobalScopes()->where('role', 'director')->count();

        return [
            Stat::make('Écoles actives', $activeSchools)
                ->color('success')
                ->icon('heroicon-m-check-circle'),

            Stat::make('Écoles suspendues', $suspendedSchools)
                ->color('danger')
                ->icon('heroicon-m-no-symbol'),

            Stat::make('Directeurs', $directorsCount)
                ->color('primary')
                ->icon('heroicon-m-user-group'),
        ];
    }
}
