<?php

namespace Database\Seeders;

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

        // 4. Classes initiales pour le back-office Filament
        foreach (['CP A', 'CP B', 'CE1 A', 'CE2 A'] as $className) {
            SchoolClass::withoutGlobalScopes()->firstOrCreate([
                'school_id' => $school->id,
                'name' => $className,
            ]);
        }
    }
}
