<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\SmsGatewayInterface;
use App\Models\School;
use App\Policies\QueuePolicy;
use App\Repositories\ArrivalRepository;
use App\Repositories\Contracts\ArrivalRepositoryInterface;
use App\Repositories\Contracts\PickupRequestRepositoryInterface;
use App\Repositories\Contracts\PickupWindowRepositoryInterface;
use App\Repositories\Contracts\RepositoryInterface;
use App\Repositories\PickupRequestRepository;
use App\Repositories\PickupWindowRepository;
use App\Services\Sms\LogSmsGateway;
use App\Services\Sms\StubSmsGateway;
use Illuminate\Support\Facades\Gate;
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
            ArrivalRepositoryInterface::class,
            ArrivalRepository::class
        );
        $this->app->bind(
            PickupRequestRepositoryInterface::class,
            PickupRequestRepository::class
        );
        $this->app->bind(
            PickupWindowRepositoryInterface::class,
            PickupWindowRepository::class
        );

        // ── Service bindings ────────────────────────────────
        $this->app->bind(
            SmsGatewayInterface::class,
            function () {
                $driver = env('SMS_DRIVER', 'log');

                return match ($driver) {
                    'stub' => new StubSmsGateway,
                    default => new LogSmsGateway,
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

        // Policies
        Gate::policy(School::class, QueuePolicy::class);
    }
}
