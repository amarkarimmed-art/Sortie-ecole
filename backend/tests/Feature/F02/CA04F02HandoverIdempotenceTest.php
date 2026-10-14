<?php

declare(strict_types=1);

namespace Tests\Feature\F02;

use App\Models\Child;
use App\Models\HandoverLog;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

/**
 * Tests d'acceptation — F02 : Tablette d'accueil
 * CA4 : Validation de la remise (handover) avec idempotence obligatoire.
 *
 * Scénarios couverts :
 *  - Exigence de l'en-tête Idempotency-Key (UUID v4).
 *  - Transition vers handed_over depuis tout statut actif.
 *  - Écriture immuable dans handover_logs (une seule ligne).
 *  - Rejeu réseau identique → HTTP 409 + ZÉRO doublon dans handover_logs.
 *  - Tentative de remise sur statut terminal (cancelled/expired) → HTTP 422.
 *
 * Ces tests doivent être ROUGES jusqu'à l'implémentation de HandoverAction.
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de ce fichier de test
// ─────────────────────────────────────────────────────────────────────────────
function makeHandoverSetup(): array
{
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
    ]);

    return compact('school', 'agent', 'parent', 'child', 'request');
}

// ─────────────────────────────────────────────────────────────────────────────
// CA4-a : L'en-tête Idempotency-Key est obligatoire — HTTP 422 si absent
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Un handover sans en-tête Idempotency-Key reçoit HTTP 422', function () {
    $setup = makeHandoverSetup();
    ['school' => $school, 'agent' => $agent, 'request' => $request] = $setup;

    Sanctum::actingAs($agent);

    // Requête sans Idempotency-Key
    $response = $this->postJson(
        "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
        ['collector_type' => HandoverLog::COLLECTOR_PARENT]
    );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(422);
    $response->assertJsonValidationErrorFor('idempotency_key');

    // Aucun log ne doit avoir été créé
    $this->assertDatabaseCount('handover_logs', 0);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-b : Handover nominal — transition vers handed_over + écriture en DB
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Un handover valide passe la demande à handed_over et écrit dans handover_logs', function () {
    $setup = makeHandoverSetup();
    ['school' => $school, 'agent' => $agent, 'parent' => $parent, 'request' => $request] = $setup;

    Carbon::setTestNow(Carbon::create(2026, 10, 13, 15, 30, 0, 'Africa/Casablanca'));

    Sanctum::actingAs($agent);

    $idempotencyKey = (string) Str::uuid();

    $response = $this->withHeader('Idempotency-Key', $idempotencyKey)
        ->postJson(
            "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
            [
                'collector_type' => HandoverLog::COLLECTOR_PARENT,
                'parent_user_id' => $parent->id,
            ]
        );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(201);

    // Vérifier la structure de la réponse (HandoverLog JSON)
    $response->assertJsonStructure([
        'id',
        'pickup_request_id',
        'school_id',
        'agent_id',
        'collector_type',
        'created_at',
    ]);
    $response->assertJsonPath('collector_type', HandoverLog::COLLECTOR_PARENT);
    $response->assertJsonPath('pickup_request_id', $request->id);

    // Vérifier la transition d'état en base
    $this->assertDatabaseHas('pickup_requests', [
        'id' => $request->id,
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);

    // Vérifier l'écriture dans le journal
    $this->assertDatabaseHas('handover_logs', [
        'pickup_request_id' => $request->id,
        'school_id' => $school->id,
        'agent_id' => $agent->id,
        'collector_type' => HandoverLog::COLLECTOR_PARENT,
        'idempotency_key' => $idempotencyKey,
    ]);

    // Exactement UNE ligne dans handover_logs
    $this->assertDatabaseCount('handover_logs', 1);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-c : Handover depuis statut class_notified (raccourci agent autorisé)
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Un handover est possible depuis le statut class_notified (raccourci agent)', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_CLASS_NOTIFIED, // statut intermédiaire
    ]);

    Sanctum::actingAs($agent);

    $response = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson(
            "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
            ['collector_type' => HandoverLog::COLLECTOR_PARENT]
        );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(201);

    $this->assertDatabaseHas('pickup_requests', [
        'id' => $request->id,
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-d : Idempotence — Rejeu réseau avec la même clé → HTTP 409 + zéro doublon
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Un rejeu réseau avec la même Idempotency-Key retourne 409 et ne crée pas de doublon', function () {
    $setup = makeHandoverSetup();
    ['school' => $school, 'agent' => $agent, 'request' => $request] = $setup;

    Sanctum::actingAs($agent);

    $idempotencyKey = (string) Str::uuid();
    $payload = ['collector_type' => HandoverLog::COLLECTOR_PARENT];

    // Premier envoi — nominal (doit créer le log)
    $firstResponse = $this->withHeader('Idempotency-Key', $idempotencyKey)
        ->postJson(
            "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
            $payload
        );

    // Deuxième envoi — rejeu avec la même clé (simule une coupure réseau)
    $secondResponse = $this->withHeader('Idempotency-Key', $idempotencyKey)
        ->postJson(
            "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
            $payload
        );

    // Doit être ROUGE jusqu'à l'implémentation :
    //   - Premier envoi : 201 Created
    //   - Second envoi : 409 Conflict (idempotent — log déjà existant renvoyé)
    $firstResponse->assertStatus(201);
    $secondResponse->assertStatus(409);

    // Le 409 doit renvoyer le HandoverLog original (pas un nouveau)
    expect($secondResponse->json('id'))->toBe($firstResponse->json('id'));

    // CRITIQUE : Une seule ligne dans handover_logs — jamais de doublon
    $this->assertDatabaseCount('handover_logs', 1);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-e : Tentative de remise sur statut terminal (cancelled) → HTTP 422
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Un handover sur une demande annulée (cancelled) retourne HTTP 422', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_CANCELLED, // statut terminal
    ]);

    Sanctum::actingAs($agent);

    $response = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson(
            "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover",
            ['collector_type' => HandoverLog::COLLECTOR_PARENT]
        );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(422);

    // Aucun log ne doit être créé
    $this->assertDatabaseCount('handover_logs', 0);

    // La demande reste au statut cancelled (pas de mutation)
    $this->assertDatabaseHas('pickup_requests', [
        'id' => $request->id,
        'status' => PickupRequest::STATUS_CANCELLED,
    ]);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-f : Le trigger PostgreSQL rend handover_logs vraiment immuable
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : Le trigger PostgreSQL interdit toute modification dans handover_logs (append-only)', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);

    // Créer un HandoverLog directement (comme si la remise avait déjà été effectuée)
    $log = HandoverLog::create([
        'id' => (string) Str::uuid(),
        'school_id' => $school->id,
        'pickup_request_id' => $request->id,
        'agent_id' => $agent->id,
        'collector_type' => HandoverLog::COLLECTOR_PARENT,
        'parent_user_id' => $parent->id,
        'idempotency_key' => (string) Str::uuid(),
        'created_at' => now(),
    ]);

    // Le trigger DOIT lever une exception si on tente une modification
    // (encapsulé dans DB::transaction pour que le rollback du savepoint n'avorte pas la transaction de test)
    expect(function () use ($log) {
        DB::transaction(function () use ($log) {
            $log->update(['collector_type' => HandoverLog::COLLECTOR_DAILY_CODE]);
        });
    })->toThrow(QueryException::class);

    // Le log original est inchangé en base
    $this->assertDatabaseHas('handover_logs', [
        'id' => $log->id,
        'collector_type' => HandoverLog::COLLECTOR_PARENT,
    ]);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-g : confirm-presence — transition pending_agent_confirmation → requested
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : confirm-presence fait passer le statut de pending_agent_confirmation à requested', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
    ]);

    Sanctum::actingAs($agent);

    $response = $this->postJson(
        "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/confirm-presence"
    );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(200);
    $response->assertJsonPath('id', $request->id);
    $response->assertJsonPath('status', PickupRequest::STATUS_REQUESTED);

    $this->assertDatabaseHas('pickup_requests', [
        'id' => $request->id,
        'status' => PickupRequest::STATUS_REQUESTED,
    ]);
})->group('F02', 'CA4');

// ─────────────────────────────────────────────────────────────────────────────
// CA4-h : confirm-presence sur un statut incompatible (requested) → HTTP 422
// ─────────────────────────────────────────────────────────────────────────────
test('CA4 [rouge] : confirm-presence sur une demande déjà à requested retourne HTTP 422', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);

    $request = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED, // statut incompatible
    ]);

    Sanctum::actingAs($agent);

    $response = $this->postJson(
        "/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/confirm-presence"
    );

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(422);

    // Le statut ne doit pas avoir changé
    $this->assertDatabaseHas('pickup_requests', [
        'id' => $request->id,
        'status' => PickupRequest::STATUS_REQUESTED,
    ]);
})->group('F02', 'CA4');
