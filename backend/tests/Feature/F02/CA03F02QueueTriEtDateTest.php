<?php

declare(strict_types=1);

namespace Tests\Feature\F02;

use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Laravel\Sanctum\Sanctum;

/**
 * Tests d'acceptation — F02 : Tablette d'accueil
 * CA3 : Filtrage strict sur la journée en cours (fuseau Africa/Casablanca)
 *       et tri chronologique ascendant.
 *
 * Points de vigilance critiques :
 *  - Une implémentation naïve utilisant UTC échouera aux tests de minuit,
 *    car 00:00:00 Africa/Casablanca = 23:00:00 UTC la veille.
 *  - Les tests gelent le temps à 23h15 Casablanca (= 22h15 UTC) pour attraper
 *    les implémentations défaillantes.
 *
 * Ces tests doivent être ROUGES jusqu'à l'implémentation de GetQueueAction.
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

// ─────────────────────────────────────────────────────────────────────────────
// CA3-a : Seules les demandes actives DU JOUR apparaissent dans la file
// ─────────────────────────────────────────────────────────────────────────────
test('CA3 [rouge] : La file ne contient que les demandes actives créées aujourd\'hui (Africa/Casablanca)', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    // Figer le temps : lundi 13 octobre 2026 à 15h30 (heure de Casablanca)
    $now = Carbon::create(2026, 10, 13, 15, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    $childToday = Child::factory()->create(['school_id' => $school->id]);
    $childYesterday = Child::factory()->create(['school_id' => $school->id]);

    // Demande d'aujourd'hui (doit apparaître)
    $requestToday = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $childToday->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => $now,
    ]);

    // Demande d'hier (ne doit PAS apparaître)
    $requestYesterday = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $childYesterday->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => $now->copy()->subDay(),
    ]);

    Sanctum::actingAs($agent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(200);
    $response->assertJsonCount(1); // Uniquement la demande d'aujourd'hui
    $response->assertJsonPath('0.id', $requestToday->id);

    // Vérifier que la demande d'hier est absente
    $ids = collect($response->json())->pluck('id');
    expect($ids->contains($requestYesterday->id))->toBeFalse(
        "La demande d'hier ne doit pas apparaître dans la file du jour."
    );
})->group('F02', 'CA3');

// ─────────────────────────────────────────────────────────────────────────────
// CA3-b : Piège Fuseau Horaire — 23h15 Casablanca (= 22h15 UTC)
//
// Une implémentation naïve utilisant whereDate('created_at', today()) en UTC
// INCLURA à tort les demandes de la veille après 23h00 Casablanca.
// Ce test détecte ce bug de décalage critique.
// ─────────────────────────────────────────────────────────────────────────────
test('CA3 [rouge] : Piège fuseau — à 23h15 Casablanca, seules les demandes du MÊME jour calendaire Casablanca sont retournées', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    // Figer le temps à 23h15 Casablanca (= 22h15 UTC) — PIÈGE DE DÉCALAGE
    // À cet instant, pour une implémentation naïve UTC :
    //   date('Y-m-d') = la veille UTC, mais c'est ENCORE aujourd'hui à Casablanca
    $casaNow = Carbon::create(2026, 10, 13, 23, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($casaNow);

    $childEarlyToday = Child::factory()->create(['school_id' => $school->id]);
    $childLateToday = Child::factory()->create(['school_id' => $school->id]);

    // Demande créée tôt le matin (09h00 Casablanca = 08h00 UTC) → DOIT apparaître
    $requestMorning = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $childEarlyToday->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => Carbon::create(2026, 10, 13, 9, 0, 0, 'Africa/Casablanca'),
    ]);

    // Demande créée à 23h10 Casablanca (= 22h10 UTC, veille UTC) → DOIT apparaître
    $requestLateEvening = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $childLateToday->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_CLASS_NOTIFIED,
        'created_at' => Carbon::create(2026, 10, 13, 23, 10, 0, 'Africa/Casablanca'),
    ]);

    Sanctum::actingAs($agent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE jusqu'à l'implémentation
    $response->assertStatus(200);

    // Les deux demandes du 13 octobre (heure Casablanca) doivent être présentes
    $response->assertJsonCount(2);

    $ids = collect($response->json())->pluck('id');
    expect($ids->contains($requestMorning->id))->toBeTrue(
        'La demande du matin doit figurer dans la file.'
    );
    expect($ids->contains($requestLateEvening->id))->toBeTrue(
        'La demande de 23h10 Casablanca doit figurer dans la file — même si UTC indique la veille.'
    );
})->group('F02', 'CA3');

// ─────────────────────────────────────────────────────────────────────────────
// CA3-c : Les statuts terminaux (handed_over, cancelled, expired) sont exclus
// ─────────────────────────────────────────────────────────────────────────────
test('CA3 [rouge] : Les demandes avec statuts terminaux ne figurent PAS dans la file', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    $now = Carbon::create(2026, 10, 13, 15, 0, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    $terminalStatuses = [
        PickupRequest::STATUS_HANDED_OVER,
        PickupRequest::STATUS_CANCELLED,
        PickupRequest::STATUS_EXPIRED,
    ];

    $activeStatuses = [
        PickupRequest::STATUS_REQUESTED,
        PickupRequest::STATUS_PENDING_AGENT_CONFIRMATION,
        PickupRequest::STATUS_CLASS_NOTIFIED,
        PickupRequest::STATUS_ON_THE_WAY,
    ];

    $terminalRequests = collect();
    $activeRequests = collect();

    foreach ($terminalStatuses as $status) {
        $child = Child::factory()->create(['school_id' => $school->id]);
        $terminalRequests->push(PickupRequest::factory()->create([
            'school_id' => $school->id,
            'child_id' => $child->id,
            'requested_by' => $parent->id,
            'status' => $status,
            'created_at' => $now,
        ]));
    }

    foreach ($activeStatuses as $status) {
        $child = Child::factory()->create(['school_id' => $school->id]);
        $activeRequests->push(PickupRequest::factory()->create([
            'school_id' => $school->id,
            'child_id' => $child->id,
            'requested_by' => $parent->id,
            'status' => $status,
            'created_at' => $now,
        ]));
    }

    Sanctum::actingAs($agent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE jusqu'à l'implémentation
    $response->assertStatus(200);

    // Exactement 4 demandes actives (une par statut actif)
    $response->assertJsonCount(count($activeStatuses));

    $ids = collect($response->json())->pluck('id');

    // Aucun statut terminal ne doit figurer dans la réponse
    foreach ($terminalRequests as $terminalReq) {
        expect($ids->contains($terminalReq->id))->toBeFalse(
            "La demande au statut '{$terminalReq->status}' ne doit pas figurer dans la file active."
        );
    }

    // Toutes les demandes actives doivent y être
    foreach ($activeRequests as $activeReq) {
        expect($ids->contains($activeReq->id))->toBeTrue(
            "La demande au statut '{$activeReq->status}' doit figurer dans la file active."
        );
    }
})->group('F02', 'CA3');

// ─────────────────────────────────────────────────────────────────────────────
// CA3-d : Tri chronologique ascendant (premier arrivé = premier dans la liste)
// ─────────────────────────────────────────────────────────────────────────────
test('CA3 [rouge] : La file est triée chronologiquement par heure de signalement (ascendant)', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'director']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    $now = Carbon::create(2026, 10, 13, 16, 0, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    // Créer 3 demandes intentionnellement dans le mauvais ordre
    $child3 = Child::factory()->create(['school_id' => $school->id]);
    $child1 = Child::factory()->create(['school_id' => $school->id]);
    $child2 = Child::factory()->create(['school_id' => $school->id]);

    $req3 = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child3->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => Carbon::create(2026, 10, 13, 15, 45, 0, 'Africa/Casablanca'),
    ]);

    $req1 = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child1->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => Carbon::create(2026, 10, 13, 15, 20, 0, 'Africa/Casablanca'),
    ]);

    $req2 = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child2->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_ON_THE_WAY,
        'created_at' => Carbon::create(2026, 10, 13, 15, 35, 0, 'Africa/Casablanca'),
    ]);

    Sanctum::actingAs($agent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE jusqu'à l'implémentation
    $response->assertStatus(200);
    $response->assertJsonCount(3);

    $ids = collect($response->json())->pluck('id')->values();

    // Ordre attendu : req1 (15h20) → req2 (15h35) → req3 (15h45)
    expect($ids->get(0))->toBe($req1->id, 'Le premier arrivé (15h20) doit être en tête de file.');
    expect($ids->get(1))->toBe($req2->id, 'Le deuxième arrivé (15h35) doit être en deuxième position.');
    expect($ids->get(2))->toBe($req3->id, 'Le dernier arrivé (15h45) doit être en queue de file.');
})->group('F02', 'CA3');

// ─────────────────────────────────────────────────────────────────────────────
// CA3-e : Structure QueueItem — Les champs enrichis sont présents dans la réponse
// ─────────────────────────────────────────────────────────────────────────────
test('CA3 [rouge] : Chaque élément de la file expose le schéma QueueItem enrichi', function () {
    $school = School::factory()->create();
    $agent = User::factory()->create(['school_id' => $school->id, 'role' => 'concierge']);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    $now = Carbon::create(2026, 10, 13, 15, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    $child = Child::factory()->create([
        'school_id' => $school->id,
        'first_name' => 'Yasmine',
        'last_name' => 'El Fassi',
        'class_name' => 'CE2-A',
    ]);

    PickupRequest::factory()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'status' => PickupRequest::STATUS_REQUESTED,
        'created_at' => $now,
    ]);

    Sanctum::actingAs($agent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE jusqu'à l'implémentation complète du QueueItem DTO
    $response->assertStatus(200);
    $response->assertJsonCount(1);

    // Vérification du schéma QueueItem (cf. openapi.yaml — schéma QueueItem)
    $response->assertJsonStructure([
        '*' => [
            'id',
            'child_id',
            'child_name',
            'class_name',
            'status',
            'created_at',
            // waiting_zone et photo_url sont nullable — pas dans le required
        ],
    ]);

    // Les données personnelles interdites ne doivent JAMAIS apparaître
    $response->assertJsonMissing(['phone']);
    $response->assertJsonMissing(['lat']);
    $response->assertJsonMissing(['lng']);
    $response->assertJsonMissing(['latitude']);
    $response->assertJsonMissing(['longitude']);
})->group('F02', 'CA3');
