<?php

/*
|--------------------------------------------------------------------------
| API Routes — Sortie d'école
|--------------------------------------------------------------------------
|
| API pure JSON. Toutes les routes sous /v1/.
| Pas de routes web (pas de Blade/HTML).
|
| Chaîne : Request → Controller → Action → Service → Repository → Model → DB
|
*/

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // ── Routes publiques ────────────────────────────────────
    // Route::post('/auth/login', ...);

    // ── Routes protégées (Sanctum) ──────────────────────────
    Route::middleware('auth:sanctum')->group(function () {
        // ── F03 : « Je suis arrivé » (Squelette — 501 Not Implemented) ──
        Route::post('/schools/{school}/arrivals', function () {
            return response()->json([
                'message' => 'Not Implemented — F03 Je suis arrivé',
            ], 501);
        })->name('arrivals.store');

        Route::get('/schools/{school}/arrivals/status', function () {
            return response()->json([
                'message' => 'Not Implemented — F03 Statut arrivée',
            ], 501);
        })->name('arrivals.status');
    });
});
