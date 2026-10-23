<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\School;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class RepairDirectorAccountsCommand extends Command
{
    protected $signature = 'accounts:repair-directors';

    protected $description = 'Nettoie les emails des utilisateurs et répare les comptes directeurs (dont yakada.admin@ecole.ma)';

    public function handle(): int
    {
        $this->info('1. Nettoyage de la casse et des espaces sur tous les emails...');

        // Justifié : Nettoyage global sur tous les utilisateurs sans restriction d'école
        $users = User::withoutGlobalScopes()->get();
        $cleaned = 0;

        foreach ($users as $user) {
            if ($user->email !== null) {
                $trimmed = strtolower(trim($user->email));
                if ($trimmed !== $user->email) {
                    $user->email = $trimmed;
                    $user->save();
                    $cleaned++;
                }
            }
        }
        $this->info("Emails nettoyés : {$cleaned}/{$users->count()}");

        $this->info('2. Vérification et réparation de l\'école Groupe Scolaire ALyakada et du directeur yakada.admin@ecole.ma...');

        // Justifié : Recherche sans scope pour trouver l'école ALyakada
        $alyakadaSchool = School::withoutGlobalScopes()
            ->where('name', 'ilike', '%alyakada%')
            ->first();

        if (! $alyakadaSchool) {
            $alyakadaSchool = School::create([
                'name' => 'Groupe Scolaire ALyakada',
                'is_suspended' => false,
            ]);
            $this->info("École ALyakada créée avec l'id : {$alyakadaSchool->id}");
        } else {
            $alyakadaSchool->is_suspended = false;
            $alyakadaSchool->save();
            $this->info("École ALyakada trouvée (id: {$alyakadaSchool->id}), is_suspended forcé à false");
        }

        // Justifié : Recherche du compte yakada.admin@ecole.ma sans global scope
        $yakadaUser = User::withoutGlobalScopes()
            ->whereRaw('LOWER(email) = ?', ['yakada.admin@ecole.ma'])
            ->first();

        if (! $yakadaUser) {
            // Justifié : Création du compte yakada sans global scope
            $yakadaUser = User::withoutGlobalScopes()->create([
                'school_id' => $alyakadaSchool->id,
                'name'      => $alyakadaSchool->name,
                'email'     => 'yakada.admin@ecole.ma',
                'password'  => Hash::make('123456'),
                'role'      => 'director',
                'phone'     => null,
            ]);
            $this->info("Compte yakada.admin@ecole.ma créé avec succès.");
        } else {
            $yakadaUser->school_id = $alyakadaSchool->id;
            $yakadaUser->role = 'director';
            $yakadaUser->password = Hash::make('123456');
            $yakadaUser->email = 'yakada.admin@ecole.ma';
            $yakadaUser->save();
            $this->info("Compte yakada.admin@ecole.ma réparé : role=director, password=123456, school_id={$alyakadaSchool->id}");
        }

        $this->info('3. Vérification du compte gsnejjar@sortie-ecole.ma...');

        // Justifié : Recherche du compte gsnejjar sans global scope
        $gsnejjarUser = User::withoutGlobalScopes()
            ->whereRaw('LOWER(email) = ?', ['gsnejjar@sortie-ecole.ma'])
            ->first();

        if ($gsnejjarUser) {
            $this->info("Utilisateur gsnejjar trouvé. Rôle actuel : {$gsnejjarUser->role}, school_id : {$gsnejjarUser->school_id}");
            $gsnejjarUser->role = 'director';
            if (empty($gsnejjarUser->school_id)) {
                // Justifié : Recherche sans global scope de l'école Alnejjar
                $alnejjarSchool = School::withoutGlobalScopes()
                    ->where('name', 'ilike', '%alnejjar%')
                    ->first();

                if (! $alnejjarSchool) {
                    $alnejjarSchool = School::create([
                        'name' => 'Groupe Scolaire Alnejjar',
                        'is_suspended' => false,
                    ]);
                }
                $gsnejjarUser->school_id = $alnejjarSchool->id;
            }
            $gsnejjarUser->save();
            $this->info("Compte gsnejjar@sortie-ecole.ma validé : role=director, school_id={$gsnejjarUser->school_id}");
        } else {
            $this->info("Utilisateur gsnejjar@sortie-ecole.ma non présent en base.");
        }

        $this->info('Réparation des comptes directeurs terminée avec succès.');

        return Command::SUCCESS;
    }
}
