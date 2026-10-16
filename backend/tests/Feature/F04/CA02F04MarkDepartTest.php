<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

use App\Models\Arrival;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

test('CA4 : surveillant école B appelant /depart école A reçoit HTTP 404 strict', function () {
    Event::fake();

    $schoolA = School::factory()->create();
    $schoolB = School::factory()->create();
    $surveillantB = actingAsSurveillant($schoolB);

    $requestA = PickupRequest::factory()->classNotified()->create([
        'school_id' => $schoolA->id,
    ]);

    $response = markDepart($schoolA, $requestA);

    $response->assertStatus(404);

    $requestA->refresh();
    expect($requestA->status)->toBe('class_notified');
})->group('F04', 'CA4');

test('CA5 : concierge tentant /depart reçoit HTTP 403', function () {
    $school = School::factory()->create();
    $concierge = actingAsConcierge($school);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
    ]);

    $response = markDepart($school, $request);

    $response->assertStatus(403);
})->group('F04', 'CA5');

test('CA6 : surveillant école A appelle /depart sur class_notified -> 200, on_the_way et event diffusé', function () {
    Event::fake();

    $school = School::factory()->create();
    $surveillant = actingAsSurveillant($school);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
    ]);

    $now = Carbon::create(2026, 10, 14, 15, 25, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    $response = markDepart($school, $request);

    $response->assertStatus(200);
    $response->assertJson([
        'id' => $request->id,
        'status' => 'on_the_way',
    ]);

    $request->refresh();
    expect($request->status)->toBe('on_the_way')
        ->and($request->departed_by_user_id)->toBe($surveillant->id)
        ->and($request->departed_at)->not->toBeNull();
})->group('F04', 'CA6');

test('CA7 : deux appels simultanés à /depart avec deux clés différentes renvoient 200 tous les deux (idempotence d\'état)', function () {
    Event::fake();

    $school = School::factory()->create();
    $surveillant = actingAsSurveillant($school);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
    ]);

    $key1 = (string) Str::uuid();
    $key2 = (string) Str::uuid();

    $response1 = markDepart($school, $request, $key1);
    $response1->assertStatus(200);

    $response2 = markDepart($school, $request, $key2);
    $response2->assertStatus(200);
    $response2->assertJson([
        'id' => $request->id,
        'status' => 'on_the_way',
    ]);
})->group('F04', 'CA7');

test('CA8 : deux appels simultanés à /depart avec la même clé renvoient deux réponses identiques HTTP 200', function () {
    Event::fake();

    $school = School::factory()->create();
    $surveillant = actingAsSurveillant($school);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
    ]);

    $sameKey = (string) Str::uuid();

    $response1 = markDepart($school, $request, $sameKey);
    $response1->assertStatus(200);

    $response2 = markDepart($school, $request, $sameKey);
    $response2->assertStatus(200);
    expect($response1->json())->toEqual($response2->json());
})->group('F04', 'CA8');

test('CA9 : appel ou départ sur une demande terminale (handed_over, cancelled, expired) renvoie HTTP 422', function () {
    $school = School::factory()->create();

    foreach (['handedOver', 'cancelled', 'expired'] as $state) {
        $req = PickupRequest::factory()->$state()->create([
            'school_id' => $school->id,
        ]);

        actingAsConcierge($school);
        $callRes = callClass($school, $req);
        $callRes->assertStatus(422);

        actingAsSurveillant($school);
        $departRes = markDepart($school, $req);
        $departRes->assertStatus(422);
    }
})->group('F04', 'CA9');

test('CA19 : POST /depart sur une demande encore en requested est rejeté en HTTP 422 (R4)', function () {
    $school = School::factory()->create();
    actingAsSurveillant($school);

    $request = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
    ]);

    $response = markDepart($school, $request);

    $response->assertStatus(422);
})->group('F04', 'CA19');

test('CA20 : après transition on_the_way, le parent voit on_the_way sur GET /arrivals/status', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    $arrival = Arrival::factory()->create([
        'school_id' => $school->id,
        'user_id' => $parent->id,
    ]);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
        'arrival_id' => $arrival->id,
    ]);

    actingAsSurveillant($school);
    $departRes = markDepart($school, $request);
    $departRes->assertStatus(200);

    // Consultation par le parent
    Sanctum::actingAs($parent);
    $statusRes = $this->getJson("/api/v1/schools/{$school->id}/arrivals/status");
    $statusRes->assertStatus(200);
    $statusRes->assertJsonFragment([
        'id' => $request->id,
        'status' => 'on_the_way',
    ]);
})->group('F04', 'CA20');

test('CA-depart-401 : utilisateur non authentifié reçoit HTTP 401 sur /depart', function () {
    $school = School::factory()->create();
    $request = PickupRequest::factory()->classNotified()->create(['school_id' => $school->id]);

    $key = (string) Str::uuid();
    $response = $this->withHeader('Idempotency-Key', $key)
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/depart");

    $response->assertStatus(401);
})->group('F04', 'auth');
