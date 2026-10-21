<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('schools', function (Blueprint $table) {
            $table->boolean('is_suspended')->default(false)->after('name');
        });

        // Migration du rôle pour le super-admin : uniquement les comptes admin sans school_id
        DB::table('users')
            ->where('role', 'admin')
            ->whereNull('school_id')
            ->update(['role' => 'super_admin']);
    }

    public function down(): void
    {
        DB::table('users')
            ->where('role', 'super_admin')
            ->whereNull('school_id')
            ->update(['role' => 'admin']);

        Schema::table('schools', function (Blueprint $table) {
            $table->dropColumn('is_suspended');
        });
    }
};
