<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Si la colonne is_suspended n'existe pas sur la table schools, l'ajouter
        if (! Schema::hasColumn('schools', 'is_suspended')) {
            Schema::table('schools', function (Blueprint $table) {
                $table->boolean('is_suspended')->default(false)->after('gate_longitude');
            });
        }

        // 2. Assure-toi que school_id et phone sur la table users sont nullable()->change()
        Schema::table('users', function (Blueprint $table) {
            $table->uuid('school_id')->nullable()->change();
            $table->string('phone')->nullable()->change();
        });

        // 3. Convertis en super_admin UNIQUEMENT les comptes ayant role = 'admin' ET school_id IS NULL
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

        if (Schema::hasColumn('schools', 'is_suspended')) {
            Schema::table('schools', function (Blueprint $table) {
                $table->dropColumn('is_suspended');
            });
        }
    }
};
