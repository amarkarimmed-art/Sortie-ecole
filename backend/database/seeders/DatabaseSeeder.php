<?php

namespace Database\Seeders;

use App\Models\School;
use App\Models\SchoolClass;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
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
            ['id' => (string) Str::uuid()]
        );

        // 2. Compte Administrateur Filament
        User::updateOrCreate(
            ['email' => 'admin@sortie-ecole.ma'],
            [
                'name' => 'Admin',
                'phone' => '+212600000000',
                'password' => 'password',
                'role' => 'admin',
                'school_id' => $school->id,
            ]
        );

        // 3. Classes initiales pour le back-office Filament
        foreach (['CP A', 'CP B', 'CE1 A', 'CE2 A'] as $className) {
            SchoolClass::firstOrCreate([
                'school_id' => $school->id,
                'name' => $className,
            ]);
        }
    }
}
