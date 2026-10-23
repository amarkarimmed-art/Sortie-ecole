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
use Illuminate\Support\Facades\Hash;

class CreateSchool extends CreateRecord
{
    protected static string $resource = SchoolResource::class;

    protected static bool $canCreateAnother = false;

    protected static ?string $title = 'Inscrire une nouvelle école';

    protected function handleRecordCreation(array $data): Model
    {
        $rawState = $this->form->getRawState();
        $schoolName = trim((string) ($data['name'] ?? $rawState['name'] ?? ''));
        $directorEmail = strtolower(trim((string) ($data['director_email'] ?? $rawState['director_email'] ?? '')));
        $directorPassword = (string) ($data['director_password'] ?? $rawState['director_password'] ?? '');

        return DB::transaction(function () use ($schoolName, $directorEmail, $directorPassword) {
            $school = School::create([
                'name' => $schoolName,
                'is_suspended' => false,
            ]);

            // Justifié : Création du compte directeur initial rattaché à la nouvelle école créée
            $director = User::withoutGlobalScopes()->create([
                'school_id' => $school->id,
                'name'      => $school->name,
                'email'     => $directorEmail,
                'password'  => Hash::make($directorPassword),
                'role'      => 'director',
                'phone'     => null,
            ]);

            session()->put('flash_director_credentials', [
                'school_name' => $school->name,
                'login'       => $director->email,
                'password'    => $directorPassword,
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
        $creds = session()->get('flash_director_credentials', []);
        $login = $creds['login'] ?? '';
        $password = $creds['password'] ?? '';

        return Notification::make()
            ->success()
            ->title('École et compte directeur créés avec succès')
            ->body("Login : {$login} | Mot de passe : {$password}")
            ->persistent();
    }
}
