<?php

declare(strict_types=1);

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Validation\ValidationException;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected function mutateFormDataBeforeSave(array $data): array
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

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
