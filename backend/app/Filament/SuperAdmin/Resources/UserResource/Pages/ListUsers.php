<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources\UserResource\Pages;

use App\Filament\SuperAdmin\Resources\UserResource;
use App\Filament\SuperAdmin\Widgets\DirectorCredentialsBannerWidget;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListUsers extends ListRecords
{
    protected static string $resource = UserResource::class;

    protected static ?string $title = 'Gestion des Directeurs';

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make()
                ->label('Ajouter un directeur')
                ->icon('heroicon-m-user-plus'),
        ];
    }

    protected function getHeaderWidgets(): array
    {
        return [
            DirectorCredentialsBannerWidget::class,
        ];
    }
}
