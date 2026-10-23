<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Widgets;

use App\Models\School;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;

class LatestSchoolsWidget extends BaseWidget
{
    protected static bool $isLazy = false;

    protected static ?int $sort = 2;

    protected static ?string $heading = '5 dernières écoles créées';

    protected int|string|array $columnSpan = 'full';

    public function table(Table $table): Table
    {
        return $table
            ->query(
                School::query()->with('director')->latest('created_at')->limit(5)
            )
            ->paginated(false)
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label("Nom de l'école")
                    ->weight('bold')
                    ->icon('heroicon-m-academic-cap'),

                Tables\Columns\TextColumn::make('director.email')
                    ->label('Login du directeur')
                    ->placeholder('Aucun directeur')
                    ->icon('heroicon-m-user'),

                Tables\Columns\TextColumn::make('is_suspended')
                    ->label('Statut')
                    ->badge()
                    ->formatStateUsing(fn (bool $state): string => $state ? 'Suspendue' : 'Active')
                    ->color(fn (bool $state): string => $state ? 'danger' : 'success'),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Date de création')
                    ->dateTime('d/m/Y H:i'),
            ]);
    }
}
