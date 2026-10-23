<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources\UserResource\Pages;

use App\Filament\SuperAdmin\Resources\UserResource;
use App\Models\School;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected static ?string $title = 'Modifier le compte directeur';

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $data['role'] = 'director';

        if (! empty($data['school_id'])) {
            // Justifié : Recherche sans global scope de l'école dans le panneau Super-Admin
            $data['name'] = School::withoutGlobalScopes()->find($data['school_id'])?->name ?? 'Directeur';
        }

        return $data;
    }

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make()
                ->label('Supprimer le compte'),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
