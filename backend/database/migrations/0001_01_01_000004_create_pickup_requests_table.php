<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table des demandes de sortie (pickup_requests) — school_id obligatoire.
 *
 * Machine à états : requested → class_notified → on_the_way → handed_over
 * Transitions secondaires : requested → cancelled | expired
 * Voir .agents/rules/domaine_et_vocabulaire.md
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pickup_requests', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                  ->constrained('schools')
                  ->cascadeOnDelete();
            $table->foreignUuid('child_id')
                  ->constrained('children')
                  ->cascadeOnDelete();
            $table->foreignUuid('requested_by')
                  ->constrained('users')
                  ->cascadeOnDelete();
            $table->string('status')->default('requested');
            // Pas de lat/lng — uniquement in_radius et distance arrondie (Loi 09-08)
            $table->boolean('in_radius')->default(false);
            $table->unsignedInteger('distance_meters')->nullable();
            $table->uuid('idempotency_key')->unique();
            $table->timestamps();

            $table->index('school_id');
            $table->index(['school_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pickup_requests');
    }
};
