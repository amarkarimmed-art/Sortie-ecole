<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('schools', function (Blueprint $table) {
            $table->unsignedInteger('perimeter_radius')->default(50)->after('is_suspended');
            $table->unsignedSmallInteger('opening_margin_minutes')->default(10)->after('perimeter_radius');
            $table->boolean('is_ramadan_mode')->default(false)->after('opening_margin_minutes');
            $table->string('manual_override_state', 20)->nullable()->after('is_ramadan_mode');
            $table->timestamp('manual_override_until')->nullable()->after('manual_override_state');
        });

        Schema::table('arrivals', function (Blueprint $table) {
            $table->string('proximity_state', 30)->default('in_perimeter')->after('in_radius');
            $table->unsignedInteger('distance_meters')->nullable()->change();
        });

        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->string('proximity_state', 30)->default('in_perimeter')->after('in_radius');
            $table->unsignedInteger('distance_meters')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('schools', function (Blueprint $table) {
            $table->dropColumn([
                'perimeter_radius',
                'opening_margin_minutes',
                'is_ramadan_mode',
                'manual_override_state',
                'manual_override_until',
            ]);
        });

        Schema::table('arrivals', function (Blueprint $table) {
            $table->dropColumn('proximity_state');
        });

        Schema::table('pickup_requests', function (Blueprint $table) {
            $table->dropColumn('proximity_state');
        });
    }
};
