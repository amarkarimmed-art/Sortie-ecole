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
        // Les routes seront ajoutées feature par feature.
        // Voir api/openapi.yaml pour le contrat d'API.
    });
});
