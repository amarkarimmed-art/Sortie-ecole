<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources\SchoolResource\Pages;

use App\Filament\SuperAdmin\Resources\SchoolResource;
use App\Models\School;
use App\Models\User;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class CreateSchool extends CreateRecord
{
    protected static string $resource = SchoolResource::class;

    protected static bool $canCreateAnother = false;

    protected static ?string $title = 'Inscrire une nouvelle école';

    protected function handleRecordCreation(array $data): Model
    {
        return DB::transaction(function () use ($data) {
            $school = School::create([
                'name' => $data['name'],
                'is_suspended' => false,
            ]);

            User::withoutGlobalScopes()->create([
                'school_id' => $school->id,
                'name'      => $school->name,
                'email'     => $data['director_email'],
                'password'  => $data['director_password'],
                'role'      => 'director',
            ]);

            session()->put('flash_director_credentials', [
                'school_name' => $school->name,
                'login'       => $data['director_email'],
                'password'    => $data['director_password'],
            ]);

            return $school;
        });
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }

    protected function getCreatedNotification(): ?Notification
    {
        return Notification::make()
            ->success()
            ->title('École et compte directeur créés avec succès')
            ->body('Les accès générés pour le directeur sont affichés ci-dessous.');
    }
}
