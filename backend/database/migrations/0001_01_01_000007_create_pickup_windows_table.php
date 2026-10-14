<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table des fenêtres de sortie par école (pickup_windows).
 *
 * Permet de définir les plages autorisées pour signaler son arrivée (F03).
 * Prévient les sorties hors créneaux (CA2, CA3) et supporte le régime Ramadan.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pickup_windows', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                ->constrained('schools')
                ->cascadeOnDelete();
            $table->unsignedTinyInteger('day_of_week'); // 1 = Lundi, 7 = Dimanche
            $table->time('start_time'); // ex: 15:20:00
            $table->time('end_time');   // ex: 16:00:00
            $table->boolean('is_ramadan')->default(false);
            $table->timestamps();

            $table->index(['school_id', 'day_of_week']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pickup_windows');
    }
};
