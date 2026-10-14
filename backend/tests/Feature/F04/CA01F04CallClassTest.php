<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

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

test('CA1 : concierge appelle une demande requested -> 200 et transition class_notified et diffusion event', function () {
    Event::fake();

    $school = School::factory()->create();
    $concierge = actingAsConcierge($school);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $request = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
    ]);

    $now = Carbon::create(2026, 10, 14, 15, 20, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    $response = callClass($school, $request);

    $response->assertStatus(200);
    $response->assertJson([
        'id' => $request->id,
        'status' => 'class_notified',
    ]);

    $request->refresh();
    expect($request->status)->toBe('class_notified')
        ->and($request->called_by_user_id)->toBe($concierge->id)
        ->and($request->called_at)->not->toBeNull();
})->group('F04', 'CA1');

test('CA2 : surveillant école B appelant /call école A reçoit HTTP 404 strict sans transition', function () {
    Event::fake();

    $schoolA = School::factory()->create();
    $schoolB = School::factory()->create();
    $surveillantB = actingAsSurveillant($schoolB);

    $requestA = PickupRequest::factory()->requested()->create([
        'school_id' => $schoolA->id,
    ]);

    $response = callClass($schoolA, $requestA);

    $response->assertStatus(404);

    $requestA->refresh();
    expect($requestA->status)->toBe('requested')
        ->and($requestA->called_at)->toBeNull();
})->group('F04', 'CA2');

test('CA3 : parent appelant /call sur sa propre école reçoit HTTP 403', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    Sanctum::actingAs($parent);

    $request = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'requested_by' => $parent->id,
    ]);

    $response = callClass($school, $request);

    $response->assertStatus(403);
})->group('F04', 'CA3');

test('CA10 : /call sur demande déjà class_notified renvoie 200 sans nouvelle transition (idempotence)', function () {
    Event::fake();

    $school = School::factory()->create();
    $concierge = actingAsConcierge($school);
    $initialCalledAt = Carbon::create(2026, 10, 14, 15, 20, 0, 'Africa/Casablanca');

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
        'called_at' => $initialCalledAt,
    ]);

    // Deuxième appel ultérieur
    Carbon::setTestNow(Carbon::create(2026, 10, 14, 15, 25, 0, 'Africa/Casablanca'));

    $response = callClass($school, $request);

    $response->assertStatus(200);
    $response->assertJson([
        'id' => $request->id,
        'status' => 'class_notified',
    ]);

    $request->refresh();
    // called_at original conservé
    expect($request->status)->toBe('class_notified')
        ->and($request->called_at->toISOString())->toBe($initialCalledAt->toISOString());
})->group('F04', 'CA10');

test('CA-call-401 : utilisateur non authentifié reçoit HTTP 401 sur /call', function () {
    $school = School::factory()->create();
    $request = PickupRequest::factory()->requested()->create(['school_id' => $school->id]);

    $key = (string) Str::uuid();
    $response = $this->withHeader('Idempotency-Key', $key)
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/call");

    $response->assertStatus(401);
})->group('F04', 'auth');
