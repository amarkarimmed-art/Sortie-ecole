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

use App\Http\Controllers\Api\ArrivalController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\QueueController;
use App\Http\Controllers\Api\StudentImportController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    // ── Routes publiques ────────────────────────────────────
    Route::post('/auth/login', [AuthController::class, 'login'])
        ->name('auth.login');
    Route::post('/auth/verify', [AuthController::class, 'verify'])
        ->name('auth.verify');

    // ── Routes protégées (Sanctum) ──────────────────────────
    Route::middleware('auth:sanctum')->group(function () {
        // ── F01 : Import CSV élèves ─────────────────────────────
        Route::post('/schools/{school}/students/import', [StudentImportController::class, 'store'])
            ->name('students.import');

        // ── F03 : « Je suis arrivé » ────────────────────────────
        Route::post('/schools/{school}/arrivals', [ArrivalController::class, 'store'])
            ->name('arrivals.store');

        Route::get('/schools/{school}/arrivals/status', [ArrivalController::class, 'status'])
            ->name('arrivals.status');

        // ── F02 : Tablette d'accueil — File d'attente ───────────────────────
        Route::get('/schools/{school}/queue', [QueueController::class, 'index'])
            ->name('queue.index');

        Route::post('/schools/{school}/pickup-requests/{requestId}/handover', [QueueController::class, 'handover'])
            ->name('queue.handover');

        Route::post('/schools/{school}/pickup-requests/{requestId}/confirm-presence', [QueueController::class, 'confirmPresence'])
            ->name('queue.confirm-presence');

        // ── F04 : « Téléphone surveillant » ─────────────────────────
        Route::post('/schools/{school}/pickup-requests/{requestId}/call', [QueueController::class, 'callClass'])
            ->name('queue.call');

        Route::post('/schools/{school}/pickup-requests/{requestId}/depart',
            fn () => response()->json(['message' => 'Not Implemented'], 501))
            ->name('queue.depart');
    });
});
