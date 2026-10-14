<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table des utilisateurs — school_id obligatoire (ADR 0005).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                ->constrained('schools')
                ->cascadeOnDelete();
            $table->string('name');
            $table->string('phone')->unique();
            $table->string('role'); // parent, agent, surveillant, direction
            $table->string('locale', 5)->default('fr');
            $table->timestamp('phone_verified_at')->nullable();
            $table->rememberToken();
            $table->timestamps();

            $table->index('school_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
