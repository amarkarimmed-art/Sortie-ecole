<?php

declare(strict_types=1);

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Validation\ValidationException;

class CreateUser extends CreateRecord
{
    protected static string $resource = UserResource::class;

    protected static bool $canCreateAnother = false;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $allowedRoles = ['parent', 'surveillant', 'concierge'];
        if (! in_array($data['role'] ?? '', $allowedRoles, true)) {
            throw ValidationException::withMessages([
                'role' => 'Le rôle sélectionné n\'est pas autorisé.',
            ]);
        }

        $data['school_id'] = auth()->user()->school_id;

        return $data;
    }

    protected function afterCreate(): void
    {
        session()->put('flash_director_credentials', [
            'school_name' => auth()->user()?->school?->name ?? '',
            'login'       => $this->record->email,
            'password'    => $this->data['password'] ?? '',
        ]);
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
