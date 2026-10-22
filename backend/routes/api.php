<?php

/*
|--------------------------------------------------------------------------
| API Routes — Sortie d'école
|--------------------------------------------------------------------------
|
| API pure JSON.
| Authentification mobile : /api/login, /api/logout, /api/me
| Métier sous /api/v1/...
|
*/

use App\Http\Controllers\Api\ArrivalController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\QueueController;
use App\Http\Controllers\Api\StudentImportController;
use Illuminate\Support\Facades\Route;

// ── Authentification Mobile (Login + Mot de passe) ───────────
Route::post('/login', [AuthController::class, 'login'])->name('api.login');

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
});

// ── Métier V1 ────────────────────────────────────────────────
Route::prefix('v1')->group(function () {
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

        Route::post('/schools/{school}/pickup-requests/{requestId}/depart', [QueueController::class, 'markDepart'])
            ->name('queue.depart');
    });
});
