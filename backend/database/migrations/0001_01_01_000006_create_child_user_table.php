<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Table pivot tuteurs-enfants (child_user).
 * Permet de rattacher un parent à ses enfants (fratrie).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('child_user', function (Blueprint $table) {
            $table->foreignUuid('child_id')
                ->constrained('children')
                ->cascadeOnDelete();
            $table->foreignUuid('user_id')
                ->constrained('users')
                ->cascadeOnDelete();
            $table->string('relationship')->default('parent'); // pere, mere, tuteur
            $table->timestamps();

            $table->primary(['child_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('child_user');
    }
};
