<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Table du journal de remises (handover_logs) — F02 : Tablette d'accueil.
 *
 * Append-only strict : un trigger PostgreSQL bloque tout UPDATE ou DELETE.
 * Conforme aux exigences légales (Loi 09-08, ADR 0003).
 * Colonnes GPS interdites. Numéros masqués.
 *
 * @see .agents/rules/regles_agent_securite_et_loi_09_08.md §4
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('handover_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('school_id')
                ->constrained('schools')
                ->cascadeOnDelete();
            $table->foreignUuid('pickup_request_id')
                ->constrained('pickup_requests')
                ->cascadeOnDelete();
            $table->foreignUuid('agent_id')
                ->constrained('users')
                ->cascadeOnDelete();

            // Récupérateur — identifiants opaques uniquement (Loi 09-08)
            $table->string('collector_type'); // parent | authorized_person | daily_code | pickup_card
            $table->foreignUuid('parent_user_id')
                ->nullable()
                ->constrained('users')
                ->nullOnDelete();
            $table->foreignUuid('authorized_person_id')
                ->nullable()
                ->comment('Référence AuthorizedPerson (hors périmètre MVP — nullable)');

            // Idempotence : une remise ne peut pas être dupliquée pour la même PickupRequest
            $table->uuid('idempotency_key')->unique();

            // Seul created_at est pertinent (pas d'updated_at — append-only)
            $table->timestamp('created_at')->useCurrent();

            $table->index('school_id');
            $table->index(['school_id', 'pickup_request_id']);
        });

        // ── Trigger PostgreSQL d'interdiction UPDATE/DELETE ────────────────────
        // Voir .agents/rules/regles_agent_securite_et_loi_09_08.md §4
        DB::unprepared("
            CREATE OR REPLACE FUNCTION interdire_modif_journal()
            RETURNS TRIGGER AS \$\$
            BEGIN
                RAISE EXCEPTION 'handover_logs est en ajout seul : les opérations UPDATE et DELETE sont interdites.';
            END;
            \$\$ LANGUAGE plpgsql;

            CREATE TRIGGER handover_logs_ajout_seul
            BEFORE UPDATE OR DELETE ON handover_logs
            FOR EACH ROW EXECUTE FUNCTION interdire_modif_journal();
        ");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS handover_logs_ajout_seul ON handover_logs;');
        DB::unprepared('DROP FUNCTION IF EXISTS interdire_modif_journal();');
        Schema::dropIfExists('handover_logs');
    }
};
