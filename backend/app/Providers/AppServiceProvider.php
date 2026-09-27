<?php

declare(strict_types=1);

namespace App\Providers;

use App\Repositories\Contracts\RepositoryInterface;
use Illuminate\Support\ServiceProvider;

/**
 * AppServiceProvider — Injection de dépendances.
 *
 * Chaque Repository concret est lié à son interface ici.
 * Les Actions reçoivent leurs Services et Repositories
 * par injection au constructeur (jamais de new).
 *
 * Ajouter les bindings feature par feature :
 *
 *   $this->app->bind(
 *       RepositoryInterface::class,
 *       PickupRepository::class
 *   );
 */
class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // ── Repository bindings ─────────────────────────────
        // Ajouter ici les liaisons interface → implémentation
        // au fur et à mesure des features.
        //
        // Exemple :
        // $this->app->bind(
        //     \App\Repositories\Contracts\RepositoryInterface::class,
        //     \App\Repositories\PickupRepository::class
        // );
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Fuseau horaire Africa/Casablanca (jamais de décalage fixe)
        date_default_timezone_set('Africa/Casablanca');
    }
}
