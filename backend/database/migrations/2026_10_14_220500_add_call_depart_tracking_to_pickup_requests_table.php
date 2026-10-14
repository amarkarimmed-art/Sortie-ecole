<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Migration additive F04 : suivi de l'appel et de la libération (call/depart).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->foreignUuid('called_by_user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamp('called_at')->nullable();

            $table->foreignUuid('departed_by_user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();

            $table->timestamp('departed_at')->nullable();

            $table->index('called_at');
        });
    }

    public function down(): void
    {
        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->dropForeign(['called_by_user_id']);
            $table->dropForeign(['departed_by_user_id']);
            $table->dropIndex(['called_at']);
            $table->dropColumn([
                'called_by_user_id',
                'called_at',
                'departed_by_user_id',
                'departed_at',
            ]);
        });
    }
};
