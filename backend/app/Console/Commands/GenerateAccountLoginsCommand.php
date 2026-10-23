<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\School;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

class GenerateAccountLoginsCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'accounts:generate-logins {--output= : Chemin du fichier CSV de sortie}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Génère des identifiants (login + mot de passe) pour les comptes existants sans login.';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $outputPath = $this->option('output') ?: storage_path('app/generated_logins.csv');

        // Justifié : Commande CLI de génération d'identifiants sur l'ensemble des écoles
        $users = User::withoutGlobalScopes()
            ->whereIn('role', ['parent', 'surveillant', 'concierge'])
            ->where(function ($q) {
                $q->whereNull('email')->orWhere('email', '');
            })
            ->get();

        $count = $users->count();
        $this->info("Traitement de {$count} compte(s) sans identifiant...");

        $outputDir = dirname($outputPath);
        if (! is_dir($outputDir)) {
            mkdir($outputDir, 0755, true);
        }

        $file = fopen($outputPath, 'w');
        if ($file === false) {
            $this->error("Impossible d'ouvrir le fichier en écriture : {$outputPath}");

            return self::FAILURE;
        }

        fputcsv($file, ['nom', 'ecole', 'login', 'mot_de_passe']);

        foreach ($users as $user) {
            // Justifié : Récupération de l'école de l'utilisateur sans global scope
            $school = School::withoutGlobalScopes()->find($user->school_id);
            $schoolSlug = Str::slug($school?->name ?: 'ecole', '');
            $userSlug = Str::slug($user->name ?: 'user', '.');
            $roleSlug = Str::slug($user->role ?: 'user');

            $baseLogin = "{$roleSlug}.{$userSlug}@{$schoolSlug}";
            $candidateLogin = $baseLogin;
            $counter = 1;

            // Justifié : Vérification de l'unicité du login candidat
            while (User::withoutGlobalScopes()->where('email', $candidateLogin)->exists()) {
                $candidateLogin = "{$roleSlug}.{$userSlug}{$counter}@{$schoolSlug}";
                $counter++;
            }

            $plainPassword = 'sortie' . random_int(1000, 9999);

            $user->email = $candidateLogin;
            $user->password = $plainPassword; // Hashe automatiquement grâce au cast 'hashed'
            $user->save();

            fputcsv($file, [
                $user->name,
                $school?->name ?? 'École inconnue',
                $candidateLogin,
                $plainPassword,
            ]);
        }

        fclose($file);

        $this->info("Fichier CSV généré avec succès : {$outputPath}");
        $this->info("Nombre de comptes traités : {$count}");

        return self::SUCCESS;
    }
}
