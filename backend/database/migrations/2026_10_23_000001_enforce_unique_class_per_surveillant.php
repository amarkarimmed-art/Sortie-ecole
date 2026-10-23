<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('school_class_user')) {
            Schema::create('school_class_user', function (Blueprint $table) {
                $table->foreignUuid('school_class_id')->constrained('school_classes')->cascadeOnDelete();
                $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
                $table->timestamps();

                $table->unique('school_class_id');
            });
        } else {
            // Nettoie d'éventuels doublons sur school_class_id dans school_class_user
            DB::statement("
                DELETE FROM school_class_user a USING school_class_user b
                WHERE a.ctid < b.ctid AND a.school_class_id = b.school_class_id
            ");

            $indexes = collect(Schema::getIndexes('school_class_user'))->pluck('name')->all();
            if (! in_array('school_class_user_school_class_id_unique', $indexes, true)) {
                Schema::table('school_class_user', function (Blueprint $table) {
                    $table->unique('school_class_id');
                });
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('school_class_user')) {
            $indexes = collect(Schema::getIndexes('school_class_user'))->pluck('name')->all();
            if (in_array('school_class_user_school_class_id_unique', $indexes, true)) {
                Schema::table('school_class_user', function (Blueprint $table) {
                    $table->dropUnique('school_class_user_school_class_id_unique');
                });
            }
        }
    }
};
