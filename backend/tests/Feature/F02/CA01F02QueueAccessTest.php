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
 * CA1 : Restriction d'accès à la file d'attente
 * CA2 : Isolation inter-école stricte (retour 404, jamais 403)
 *
 * Ces tests doivent être ROUGES jusqu'à l'implémentation de QueuePolicy et GetQueueAction.
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

// ─────────────────────────────────────────────────────────────────────────────
// CA1-a : Un parent (rôle insuffisant) reçoit HTTP 403 — pas d'accès à la file
// ─────────────────────────────────────────────────────────────────────────────
test('CA1 [rouge] : Un utilisateur avec le rôle parent reçoit HTTP 403 sur GET /queue', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create([
        'school_id' => $school->id,
        'role' => 'parent',
    ]);

    Sanctum::actingAs($parent);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation de la policy
    $response->assertStatus(403);
})->group('F02', 'CA1');

// ─────────────────────────────────────────────────────────────────────────────
// CA1-b : Un surveillant (rôle non autorisé) reçoit HTTP 403
// ─────────────────────────────────────────────────────────────────────────────
test('CA1 [rouge] : Un utilisateur avec le rôle surveillant reçoit HTTP 403 sur GET /queue', function () {
    $school = School::factory()->create();
    $surveillant = User::factory()->create([
        'school_id' => $school->id,
        'role' => 'surveillant',
    ]);

    Sanctum::actingAs($surveillant);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation de la policy
    $response->assertStatus(403);
})->group('F02', 'CA1');

// ─────────────────────────────────────────────────────────────────────────────
// CA1-c : Un utilisateur non authentifié reçoit HTTP 401
// ─────────────────────────────────────────────────────────────────────────────
test('CA1 [rouge] : Un utilisateur non authentifié reçoit HTTP 401 sur GET /queue', function () {
    $school = School::factory()->create();

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    $response->assertStatus(401);
    // Ce test passera immédiatement grâce au middleware auth:sanctum — pas de logique à implémenter
})->group('F02', 'CA1');

// ─────────────────────────────────────────────────────────────────────────────
// CA1-d : Un concierge de l'école reçoit HTTP 200 (pas 403)
// ─────────────────────────────────────────────────────────────────────────────
test('CA1 [rouge] : Un agent avec le rôle concierge reçoit au minimum HTTP 200 (pas 403/501)', function () {
    $school = School::factory()->create();
    $concierge = User::factory()->create([
        'school_id' => $school->id,
        'role' => 'concierge',
    ]);

    Sanctum::actingAs($concierge);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation complète
    $response->assertStatus(200);
    $response->assertJsonIsArray();
})->group('F02', 'CA1');

// ─────────────────────────────────────────────────────────────────────────────
// CA1-e : Un directeur de l'école reçoit HTTP 200
// ─────────────────────────────────────────────────────────────────────────────
test('CA1 [rouge] : Un agent avec le rôle director reçoit au minimum HTTP 200 (pas 403/501)', function () {
    $school = School::factory()->create();
    $director = User::factory()->create([
        'school_id' => $school->id,
        'role' => 'director',
    ]);

    Sanctum::actingAs($director);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation complète
    $response->assertStatus(200);
    $response->assertJsonIsArray();
})->group('F02', 'CA1');

// ─────────────────────────────────────────────────────────────────────────────
// CA2-a : Agent école A → file école B → HTTP 404 (étanchéité absolue)
// Règle ADR 0005 : "jamais 403, toujours 404" pour ne pas fuiter l'existence
// ─────────────────────────────────────────────────────────────────────────────
test('CA2 [rouge] : Un agent de l\'école A demandant la file de l\'école B reçoit HTTP 404', function () {
    $schoolA = School::factory()->create(['name' => 'École Al Farouk']);
    $schoolB = School::factory()->create(['name' => 'École Ibn Sina']);

    $agentA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role' => 'concierge',
    ]);

    Sanctum::actingAs($agentA);

    // L'agent A tente d'accéder à la file de l'école B
    $response = $this->getJson("/api/v1/schools/{$schoolB->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation de l'isolation
    // Exigence ADR 0005 : HTTP 404 (jamais 403 pour éviter la fuite d'existence)
    $response->assertStatus(404);
    // Vérifier que le corps de la réponse ne contient AUCUNE donnée de l'école B
    $response->assertJsonMissing(['École Ibn Sina']);
})->group('F02', 'CA2');

// ─────────────────────────────────────────────────────────────────────────────
// CA2-b : Le corps de l'erreur 404 ne révèle pas si l'école existe ou non
// ─────────────────────────────────────────────────────────────────────────────
test('CA2 [rouge] : La réponse 404 inter-école ne révèle pas l\'existence de l\'école B', function () {
    $schoolA = School::factory()->create();
    $schoolB = School::factory()->create();

    $agentA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role' => 'director',
    ]);

    $childB = Child::factory()->create(['school_id' => $schoolB->id]);

    // Créer une demande dans la file de l'école B
    PickupRequest::factory()->create([
        'school_id' => $schoolB->id,
        'child_id' => $childB->id,
        'status' => PickupRequest::STATUS_REQUESTED,
    ]);

    Sanctum::actingAs($agentA);

    $response = $this->getJson("/api/v1/schools/{$schoolB->id}/queue");

    // Doit être ROUGE : reçoit 501 jusqu'à l'implémentation
    $response->assertStatus(404);

    // Aucune donnée de la demande de l'école B ne doit apparaître
    $response->assertJsonMissing(['child_id' => $childB->id]);
})->group('F02', 'CA2');
