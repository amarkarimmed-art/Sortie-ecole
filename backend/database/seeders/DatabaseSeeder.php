<?php

namespace Database\Seeders;

use App\Models\Child;
use App\Models\School;
use App\Models\SchoolClass;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/**
 * Seeder principal — données fictives uniquement.
 * Aucune donnée réelle (conformité Loi 09-08 / CNDP).
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. École pilote
        $school = School::firstOrCreate(
            ['name' => 'École Al Amal'],
            ['id' => (string) Str::uuid(), 'is_suspended' => false]
        );
        $school->update(['is_suspended' => false]);

        // 2. Compte Super-Admin
        User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'superadmin@sortie-ecole.ma'],
            [
                'name' => 'Super Admin',
                'phone' => '+212600000001',
                'password' => 'password',
                'role' => 'super_admin',
                'school_id' => null,
            ]
        );

        // 3. Compte Administrateur Filament École
        User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'admin@sortie-ecole.ma'],
            [
                'name' => 'Admin École Al Amal',
                'phone' => '+212600000000',
                'password' => 'password',
                'role' => 'admin',
                'school_id' => $school->id,
            ]
        );

        // 4. Compte Directeur École
        User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'director@sortie-ecole.ma'],
            [
                'name' => $school->name,
                'phone' => '+212600000002',
                'password' => 'password',
                'role' => 'director',
                'school_id' => $school->id,
            ]
        );

        // 5. Classes initiales pour le back-office Filament
        foreach (['CP A', 'CP B', 'CE1 A', 'CE2 A'] as $className) {
            SchoolClass::withoutGlobalScopes()->firstOrCreate([
                'school_id' => $school->id,
                'name' => $className,
            ]);
        }

        // 6. Élève de démonstration
        $child = Child::withoutGlobalScopes()->firstOrCreate(
            [
                'school_id' => $school->id,
                'first_name' => 'Sami',
                'last_name' => 'Alami',
                'class_name' => 'CP A',
            ]
        );

        // 7. Compte Parent démonstration (app_parent)
        $parent = User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'parent.alami@alamal'],
            [
                'name' => 'Oussama Alami',
                'phone' => '+212611111111',
                'password' => 'password',
                'role' => 'parent',
                'school_id' => $school->id,
                'locale' => 'fr',
            ]
        );
        if (! $child->parents()->where('users.id', $parent->id)->exists()) {
            $child->parents()->attach($parent->id, ['relationship' => 'parent']);
        }

        // 8. Compte Surveillant démonstration (app_ecole)
        $surveillant = User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'surveillant@alamal'],
            [
                'name' => 'Surveillant Al Amal',
                'phone' => '+212622222222',
                'password' => 'password',
                'role' => 'surveillant',
                'school_id' => $school->id,
                'locale' => 'fr',
            ]
        );

        // Assigner d'office les classes disponibles aux surveillants qui n'en ont pas encore
        $surveillants = User::withoutGlobalScopes()->where('role', 'surveillant')->get();
        foreach ($surveillants as $srv) {
            if ($srv->schoolClasses()->count() === 0 && $srv->school_id) {
                $availableClasses = SchoolClass::withoutGlobalScopes()
                    ->where('school_id', $srv->school_id)
                    ->whereDoesntHave('surveillants')
                    ->get();
                if ($availableClasses->isNotEmpty()) {
                    $srv->schoolClasses()->syncWithoutDetaching($availableClasses->pluck('id'));
                }
            }
        }

        // 9. Compte Concierge démonstration (app_ecole)
        User::withoutGlobalScopes()->updateOrCreate(
            ['email' => 'concierge@alamal'],
            [
                'name' => 'Concierge Al Amal',
                'phone' => '+212633333333',
                'password' => 'password',
                'role' => 'concierge',
                'school_id' => $school->id,
                'locale' => 'fr',
            ]
        );
    }
}
