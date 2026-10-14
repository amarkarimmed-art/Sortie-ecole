<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table des élèves (children) — school_id obligatoire (ADR 0005).
 * Pas de coordonnées GPS, pas de données personnelles superflues.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('children', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                ->constrained('schools')
                ->cascadeOnDelete();
            $table->string('first_name');
            $table->string('last_name');
            $table->string('class_name');
            $table->string('photo_path')->nullable(); // MinIO path, accès via URL signée
            $table->timestamps();

            $table->index('school_id');
            // Index pour détecter les homonymes (alerte tablette)
            $table->index(['school_id', 'last_name', 'first_name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('children');
    }
};
