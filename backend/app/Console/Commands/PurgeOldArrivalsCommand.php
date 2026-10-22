<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\Arrival;
use App\Models\PickupRequest;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class PurgeOldArrivalsCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'arrivals:purge-old';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Purge les arrivées et demandes de sortie de plus de 30 jours (fuseau Africa/Casablanca, Loi 09-08).';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $cutoff = Carbon::now('Africa/Casablanca')->subDays(30);

        $this->info("Purge des données antérieures au {$cutoff->toDateTimeString()} (Africa/Casablanca)...");

        $requestsDeleted = DB::transaction(function () use ($cutoff) {
            // Justifié : purge globale planifiée toutes écoles confondues
            $deletedRequests = PickupRequest::withoutGlobalScopes()
                ->where('created_at', '<', $cutoff)
                ->delete();

            // Justifié : purge globale planifiée toutes écoles confondues
            $deletedArrivals = Arrival::withoutGlobalScopes()
                ->where('created_at', '<', $cutoff)
                ->delete();

            return [$deletedRequests, $deletedArrivals];
        });

        $this->info("{$requestsDeleted[0]} demande(s) de sortie supprimée(s).");
        $this->info("{$requestsDeleted[1]} arrivée(s) supprimée(s).");
        $this->info("Le journal d'audit handover_logs a été strictement préservé.");

        return self::SUCCESS;
    }
}
