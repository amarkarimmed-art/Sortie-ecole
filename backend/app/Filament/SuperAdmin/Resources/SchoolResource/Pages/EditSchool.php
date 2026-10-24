<?php

namespace App\Filament\SuperAdmin\Resources\SchoolResource\Pages;

use App\Filament\SuperAdmin\Resources\SchoolResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditSchool extends EditRecord
{
    protected static string $resource = SchoolResource::class;

    protected static ?string $title = 'Modifier l\'école';

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make()
                ->label("Supprimer l'école")
                ->modalHeading(fn (\App\Models\School $record): string => "Supprimer l'école « {$record->name} » ?")
                ->modalDescription("Tous les comptes, classes, élèves et historiques liés à cette école seront définitivement effacés.")
                ->using(function (\App\Models\School $record): void {
                    $record->deleteEntireSchool();
                }),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
