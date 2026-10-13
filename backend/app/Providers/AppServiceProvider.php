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
        $this->app->bind(
            \App\Repositories\Contracts\ArrivalRepositoryInterface::class,
            \App\Repositories\ArrivalRepository::class
        );
        $this->app->bind(
            \App\Repositories\Contracts\PickupRequestRepositoryInterface::class,
            \App\Repositories\PickupRequestRepository::class
        );
        $this->app->bind(
            \App\Repositories\Contracts\PickupWindowRepositoryInterface::class,
            \App\Repositories\PickupWindowRepository::class
        );

        // ── Service bindings ────────────────────────────────
        $this->app->bind(
            \App\Contracts\SmsGatewayInterface::class,
            function () {
                $driver = env('SMS_DRIVER', 'log');

                return match ($driver) {
                    'stub' => new \App\Services\Sms\StubSmsGateway(),
                    default => new \App\Services\Sms\LogSmsGateway(),
                };
            }
        );
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
