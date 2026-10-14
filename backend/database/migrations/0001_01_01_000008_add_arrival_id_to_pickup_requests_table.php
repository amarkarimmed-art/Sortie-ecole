<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Ajout de arrival_id sur pickup_requests pour lier la demande individuelle à l'arrivée (fratrie).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->foreignUuid('arrival_id')
                ->nullable()
                ->after('requested_by')
                ->constrained('arrivals')
                ->nullOnDelete();

            $table->index('arrival_id');
        });
    }

    public function down(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->dropForeign(['arrival_id']);
            $table->dropColumn('arrival_id');
        });
    }
};
