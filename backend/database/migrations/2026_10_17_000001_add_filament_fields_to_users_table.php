<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable()->unique()->after('name');
            $table->string('password')->nullable()->after('email');
            $table->string('phone')->nullable()->change();
            $table->string('role')->default('admin')->change();
            $table->foreignUuid('school_id')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['email', 'password']);
            $table->string('phone')->nullable(false)->change();
            $table->string('role')->default(null)->change();
            $table->foreignUuid('school_id')->nullable(false)->change();
        });
    }
};
