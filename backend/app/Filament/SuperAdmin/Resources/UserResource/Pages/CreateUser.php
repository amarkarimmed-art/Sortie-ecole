<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources\UserResource\Pages;

use App\Filament\SuperAdmin\Resources\UserResource;
use App\Models\School;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;

class CreateUser extends CreateRecord
{
    protected static string $resource = UserResource::class;

    protected static ?string $title = 'Ajouter un directeur';

    protected static bool $canCreateAnother = false;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $school = School::withoutGlobalScopes()->findOrFail($data['school_id']);

        $data['role'] = 'director';
        $data['name'] = $school->name;
        $data['phone'] = null;

        session()->put('flash_director_credentials', [
            'school_name' => $school->name,
            'login'       => $data['email'],
            'password'    => $data['password'],
        ]);

        return $data;
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getCreatedNotification(): ?Notification
    {
        return Notification::make()
            ->success()
            ->title('Directeur créé avec succès')
            ->body('Les identifiants générés sont affichés ci-dessous.');
    }
}
