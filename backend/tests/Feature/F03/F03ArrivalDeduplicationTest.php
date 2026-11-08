<?php

declare(strict_types=1);

namespace Tests\Feature\F03;

use App\Events\ArrivalSignaledEvent;
use App\Models\Arrival;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\PickupWindow;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

/**
 * Tests — Anti-doublon intelligent et diffusion fiable.
 *
 * Couvre :
 * - Blocage 409 si une demande est en attente pour le jour en cours
 * - Autorisation d'une nouvelle demande si toutes les demandes précédentes sont terminales
 * - Blocage si seulement une partie des enfants est remise
 * - Journalisation des échecs de diffusion WebSocket
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

// --- Coordonnées de test ---
const GATE_LAT_DUP = 33.5731;
const GATE_LNG_DUP = -7.5898;
const PARENT_LAT_DUP = 33.5733;
const PARENT_LNG_DUP = -7.5896;

/**
 * Crée l'environnement de test standard : école, parent, enfant(s), fenêtre horaire.
 *
 * @param  int  $childCount  Nombre d'enfants à créer
 * @return array{school: School, parent: User, children: array<Child>}
 */
function createTestEnvironment(int $childCount = 1): array
{
    $school = School::factory()->create([
        'gate_latitude' => GATE_LAT_DUP,
        'gate_longitude' => GATE_LNG_DUP,
        'perimeter_radius' => 100,
    ]);

    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);

    $children = [];
    for ($i = 0; $i < $childCount; $i++) {
        $child = Child::factory()->create([
            'school_id' => $school->id,
            'first_name' => "Enfant{$i}",
            'last_name' => 'Test',
        ]);
        $parent->children()->attach($child->id, ['relationship' => 'parent']);
        $children[] = $child;
    }

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1, // Lundi
        'start_time' => '15:20:00',
        'end_time' => '16:00:00',
        'is_ramadan' => false,
    ]);

    // Figer le temps à un lundi à 15h30
    Carbon::setTestNow(Carbon::create(2026, 10, 5, 15, 30, 0, 'Africa/Casablanca'));

    return compact('school', 'parent', 'children');
}

/*
|--------------------------------------------------------------------------
| Demande en attente → bloque la suivante (409)
|--------------------------------------------------------------------------
*/
test('Une demande en attente bloque la demande suivante avec un code 409', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment();
    $child = $children[0];

    Sanctum::actingAs($parent);

    // Première demande → 201
    $first = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $first->assertStatus(201);

    // Deuxième demande → 409
    $second = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $second->assertStatus(409);
    $second->assertJsonStructure(['message', 'message_fr', 'message_ar', 'pending_children']);
    expect($second->json('pending_children.0.child_id'))->toBe($child->id);
});

/*
|--------------------------------------------------------------------------
| Demande remise → permet une nouvelle demande visible du surveillant
|--------------------------------------------------------------------------
*/
test('Une demande remise permet une nouvelle demande qui déclenche la diffusion', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment();
    $child = $children[0];

    Sanctum::actingAs($parent);

    // Première demande → 201
    $first = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $first->assertStatus(201);

    // Marquer la demande comme remise (handed_over)
    $requestId = $first->json('pickup_requests.0.id');
    PickupRequest::withoutGlobalScopes()->where('id', $requestId)->update([
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);

    // Écouter les événements de diffusion
    Event::fake([ArrivalSignaledEvent::class]);

    // Nouvelle demande → 201 (les demandes précédentes sont terminées)
    $second = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $second->assertStatus(201);

    // Le surveillant doit recevoir l'événement de la nouvelle arrivée
    Event::assertDispatched(ArrivalSignaledEvent::class, function (ArrivalSignaledEvent $event) use ($school) {
        return (string) $event->arrival->school_id === (string) $school->id;
    });
});

/*
|--------------------------------------------------------------------------
| Deux enfants dont un seul remis → blocage 409
|--------------------------------------------------------------------------
*/
test('Deux enfants dont un seul est remis bloquent la nouvelle demande (409)', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment(2);
    [$child1, $child2] = $children;

    Sanctum::actingAs($parent);

    // Première demande pour les deux enfants → 201
    $first = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child1->id, $child2->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $first->assertStatus(201);

    // Marquer uniquement le premier enfant comme remis
    $requests = $first->json('pickup_requests');
    $req1 = collect($requests)->firstWhere('child_id', $child1->id);
    PickupRequest::withoutGlobalScopes()->where('id', $req1['id'])->update([
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);

    // Nouvelle demande pour les deux enfants → 409 (child2 est encore en attente)
    $second = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child1->id, $child2->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $second->assertStatus(409);

    // Le message doit citer l'enfant encore en attente
    $pendingChildIds = collect($second->json('pending_children'))->pluck('child_id')->all();
    expect($pendingChildIds)->toContain($child2->id);
});

/*
|--------------------------------------------------------------------------
| La diffusion échouée est journalisée (pas de catch vide)
|--------------------------------------------------------------------------
*/
test('Un échec de diffusion WebSocket est enregistré dans les journaux', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment();
    $child = $children[0];

    Sanctum::actingAs($parent);

    // Provoquer un échec de diffusion
    Event::listen(ArrivalSignaledEvent::class, function () {
        throw new \RuntimeException('Reverb connection refused');
    });

    Log::shouldReceive('warning')
        ->once()
        ->withArgs(function (string $message, array $context) {
            return str_contains($message, 'diffusion WebSocket')
                && isset($context['arrival_id'])
                && isset($context['error']);
        });

    $response = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);

    // La demande doit réussir malgré l'échec de diffusion
    $response->assertStatus(201);
});

/*
|--------------------------------------------------------------------------
| Les coordonnées GPS sont obligatoires
|--------------------------------------------------------------------------
*/
test('Un signalement sans coordonnées GPS est rejeté', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment();
    $child = $children[0];

    Sanctum::actingAs($parent);

    $response = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        // Pas de pos_lat ni pos_lng
    ]);

    $response->assertStatus(422);
});

/*
|--------------------------------------------------------------------------
| Le statut renvoie toutes les demandes du jour
|--------------------------------------------------------------------------
*/
test('Le statut renvoie toutes les demandes du jour, pas seulement la première', function () {
    ['school' => $school, 'parent' => $parent, 'children' => $children] = createTestEnvironment();
    $child = $children[0];

    Sanctum::actingAs($parent);

    // Première demande
    $first = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $first->assertStatus(201);

    // Marquer comme remis pour permettre une deuxième demande
    $requestId = $first->json('pickup_requests.0.id');
    PickupRequest::withoutGlobalScopes()->where('id', $requestId)->update([
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);

    // Deuxième demande
    $second = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'pos_lat' => PARENT_LAT_DUP,
            'pos_lng' => PARENT_LNG_DUP,
        ]);
    $second->assertStatus(201);

    // Consulter le statut
    $status = $this->getJson("/api/v1/schools/{$school->id}/arrivals/status");
    $status->assertStatus(200);

    // Doit renvoyer les deux demandes du jour
    $pickupRequests = $status->json('pickup_requests');
    expect(count($pickupRequests))->toBeGreaterThanOrEqual(2);
});

