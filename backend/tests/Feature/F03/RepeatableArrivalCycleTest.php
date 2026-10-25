<?php

declare(strict_types=1);

namespace Tests\Feature\F03;

use App\Models\Arrival;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\PickupWindow;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

/**
 * Tests des cycles d'arrivée répétés et illimités (F03 / ADR 0005).
 *
 * Scénarios vérifiés :
 * 1. Première arrivée -> statut requested, has_active_cycle: true.
 * 2. Remise de l'enfant (handed_over) -> has_active_cycle: false.
 * 3. Deuxième arrivée le même jour (Africa/Casablanca) -> nouvelle Arrival et PickupRequest requested.
 * 4. Double clic pendant un cycle actif (requested ou on_the_way) -> pas de doublon en base, cycle réutilisé.
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

test('Scénario 1 : Première arrivée crée une Arrival et une PickupRequest en statut requested', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '15:20:00',
        'end_time' => '16:00:00',
        'is_ramadan' => false,
    ]);

    $now = Carbon::create(2026, 10, 5, 15, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    $idempotencyKey = (string) Str::uuid();

    $response = $this->withHeader('Idempotency-Key', $idempotencyKey)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 30,
            'proximity_state' => 'in_perimeter',
        ]);

    $response->assertStatus(201);

    expect(Arrival::where('school_id', $school->id)->where('user_id', $parent->id)->count())->toBe(1);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->where('status', PickupRequest::STATUS_REQUESTED)->count())->toBe(1);

    $statusRes = $this->getJson("/api/v1/schools/{$school->id}/arrivals/status");
    $statusRes->assertStatus(200);
    $statusRes->assertJson([
        'has_active_cycle' => true,
    ]);
});

test('Scénarios 2 et 3 : Après remise (handed_over), une nouvelle arrivée le même jour crée un nouveau cycle', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '15:20:00',
        'end_time' => '16:00:00',
        'is_ramadan' => false,
    ]);

    $now = Carbon::create(2026, 10, 5, 15, 25, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    // 1. Première arrivée
    $key1 = (string) Str::uuid();
    $res1 = $this->withHeader('Idempotency-Key', $key1)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 20,
            'proximity_state' => 'in_perimeter',
        ]);
    $res1->assertStatus(201);
    $firstArrivalId = $res1->json('id');

    $firstRequest = PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->first();
    expect($firstRequest)->not->toBeNull();
    expect($firstRequest->status)->toBe(PickupRequest::STATUS_REQUESTED);

    // 2. Passer la première demande en handed_over (Scénario 2)
    $firstRequest->update(['status' => PickupRequest::STATUS_HANDED_OVER]);

    // Vérifier le statut : le cycle n'est plus actif
    $statusRes = $this->getJson("/api/v1/schools/{$school->id}/arrivals/status");
    $statusRes->assertStatus(200);
    $statusRes->assertJson([
        'has_active_cycle' => false,
    ]);

    // 3. Deuxième arrivée le même jour à 15h40 avec un nouvel idempotency_key (Scénario 3)
    $nowLater = Carbon::create(2026, 10, 5, 15, 40, 0, 'Africa/Casablanca');
    Carbon::setTestNow($nowLater);

    $key2 = (string) Str::uuid();
    $res2 = $this->withHeader('Idempotency-Key', $key2)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 10,
            'proximity_state' => 'in_perimeter',
        ]);
    $res2->assertStatus(201);
    $secondArrivalId = $res2->json('id');

    expect($secondArrivalId)->not->toBe($firstArrivalId);

    // Vérifier en base : 2 arrivées et 2 demandes distinctes pour ce même enfant aujourd'hui
    expect(Arrival::where('school_id', $school->id)->where('user_id', $parent->id)->count())->toBe(2);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->count())->toBe(2);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->where('status', PickupRequest::STATUS_REQUESTED)->count())->toBe(1);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->where('status', PickupRequest::STATUS_HANDED_OVER)->count())->toBe(1);

    // Le statut courant est à nouveau actif
    $statusRes2 = $this->getJson("/api/v1/schools/{$school->id}/arrivals/status");
    $statusRes2->assertStatus(200);
    $statusRes2->assertJson([
        'has_active_cycle' => true,
    ]);
});

test('Scénario 4 : Une tentative d\'arrivée alors qu\'un cycle est actif (requested ou on_the_way) réutilise le cycle sans doublon', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '15:20:00',
        'end_time' => '16:00:00',
        'is_ramadan' => false,
    ]);

    $now = Carbon::create(2026, 10, 5, 15, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    $key1 = (string) Str::uuid();
    $res1 = $this->withHeader('Idempotency-Key', $key1)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 20,
            'proximity_state' => 'in_perimeter',
        ]);
    $res1->assertStatus(201);
    $arrivalId = $res1->json('id');

    // Deuxième clic avec une NOUVELLE clé d'idempotence pendant que la demande est 'requested'
    $key2 = (string) Str::uuid();
    $res2 = $this->withHeader('Idempotency-Key', $key2)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 20,
            'proximity_state' => 'in_perimeter',
        ]);
    expect(in_array($res2->status(), [200, 201], true))->toBeTrue();
    expect($res2->json('id'))->toBe($arrivalId);

    // Zéro doublon en base
    expect(Arrival::where('school_id', $school->id)->where('user_id', $parent->id)->count())->toBe(1);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->count())->toBe(1);

    // Passer la demande à 'on_the_way'
    PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->update([
        'status' => PickupRequest::STATUS_ON_THE_WAY,
    ]);

    // Troisième clic pendant que la demande est 'on_the_way'
    $key3 = (string) Str::uuid();
    $res3 = $this->withHeader('Idempotency-Key', $key3)
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 15,
            'proximity_state' => 'in_perimeter',
        ]);
    expect(in_array($res3->status(), [200, 201], true))->toBeTrue();
    expect($res3->json('id'))->toBe($arrivalId);

    // Toujours aucun doublon
    expect(Arrival::where('school_id', $school->id)->where('user_id', $parent->id)->count())->toBe(1);
    expect(PickupRequest::where('school_id', $school->id)->where('child_id', $child->id)->count())->toBe(1);
});
