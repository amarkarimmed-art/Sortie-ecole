<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table des arrivées (arrivals) — Regroupe les demandes de sortie d'un parent (fratrie).
 * 
 * Règle Sécurité §2 (Loi 09-08) :
 * - Aucune coordonnée GPS brute (lat/lng) n'est stockée.
 * - Uniquement in_radius (booléen) et distance_meters arrondie aux 10m supérieurs.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('arrivals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                  ->constrained('schools')
                  ->cascadeOnDelete();
            $table->foreignUuid('user_id')
                  ->constrained('users')
                  ->cascadeOnDelete();
            $table->boolean('in_radius')->default(false);
            $table->unsignedInteger('distance_meters')->nullable();
            $table->uuid('idempotency_key')->nullable()->unique();
            $table->timestamps();

            $table->index('school_id');
            $table->index(['school_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('arrivals');
    }
};
