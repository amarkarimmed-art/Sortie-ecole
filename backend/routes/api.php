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
    Route::post('/auth/login', [\App\Http\Controllers\Api\AuthController::class, 'login'])
        ->name('auth.login');
    Route::post('/auth/verify', [\App\Http\Controllers\Api\AuthController::class, 'verify'])
        ->name('auth.verify');

    // ── Routes protégées (Sanctum) ──────────────────────────
    Route::middleware('auth:sanctum')->group(function () {
        // ── F01 : Import CSV élèves ─────────────────────────────
        Route::post('/schools/{school}/students/import', [\App\Http\Controllers\Api\StudentImportController::class, 'store'])
            ->name('students.import');

        // ── F03 : « Je suis arrivé » ────────────────────────────
        Route::post('/schools/{school}/arrivals', [\App\Http\Controllers\Api\ArrivalController::class, 'store'])
            ->name('arrivals.store');

        Route::get('/schools/{school}/arrivals/status', [\App\Http\Controllers\Api\ArrivalController::class, 'status'])
            ->name('arrivals.status');
    });
});
