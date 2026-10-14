<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

use App\Models\PickupRequest;
use App\Models\School;
use Carbon\Carbon;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

test('CA12 : /queue ne contient que les demandes de l\'école du surveillant, exclut les statuts terminaux', function () {
    $schoolA = School::factory()->create();
    $schoolB = School::factory()->create();

    actingAsSurveillant($schoolA);

    // Demande active école A
    $activeA = PickupRequest::factory()->classNotified()->create([
        'school_id' => $schoolA->id,
    ]);

    // Demande active école B (ne doit pas apparaître)
    $activeB = PickupRequest::factory()->classNotified()->create([
        'school_id' => $schoolB->id,
    ]);

    // Demandes terminales école A (ne doivent pas apparaître)
    $handedOverA = PickupRequest::factory()->handedOver()->create([
        'school_id' => $schoolA->id,
    ]);
    $cancelledA = PickupRequest::factory()->cancelled()->create([
        'school_id' => $schoolA->id,
    ]);
    $expiredA = PickupRequest::factory()->expired()->create([
        'school_id' => $schoolA->id,
    ]);

    $response = $this->getJson("/api/v1/schools/{$schoolA->id}/queue");

    $response->assertStatus(200);
    $ids = collect($response->json())->pluck('id')->all();

    expect($ids)->toContain($activeA->id)
        ->and($ids)->not->toContain($activeB->id)
        ->and($ids)->not->toContain($handedOverA->id)
        ->and($ids)->not->toContain($cancelledA->id)
        ->and($ids)->not->toContain($expiredA->id);
})->group('F04', 'CA12');

test('CA22 : /queue par surveillant ne retourne que les demandes class_notified, triées called_at ascendant', function () {
    $school = School::factory()->create();
    actingAsSurveillant($school);

    $now = Carbon::create(2026, 10, 14, 15, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    // Demande appelée à 15h20
    $firstCalled = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
        'called_at' => Carbon::create(2026, 10, 14, 15, 20, 0, 'Africa/Casablanca'),
        'created_at' => Carbon::create(2026, 10, 14, 15, 05, 0, 'Africa/Casablanca'),
    ]);

    // Demande appelée à 15h25 (mais créée plus tôt à 15h00)
    $secondCalled = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
        'called_at' => Carbon::create(2026, 10, 14, 15, 25, 0, 'Africa/Casablanca'),
        'created_at' => Carbon::create(2026, 10, 14, 15, 00, 0, 'Africa/Casablanca'),
    ]);

    // Demande en requested (ne doit pas être visible par le surveillant)
    $requested = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
    ]);

    // Demande en on_the_way (disparaît de l'écran surveillant)
    $onTheWay = PickupRequest::factory()->onTheWay()->create([
        'school_id' => $school->id,
    ]);

    $response = $this->getJson("/api/v1/schools/{$school->id}/queue");

    $response->assertStatus(200);
    $items = $response->json();
    $ids = collect($items)->pluck('id')->all();

    expect($ids)->not->toContain($requested->id)
        ->and($ids)->not->toContain($onTheWay->id)
        ->and($ids)->toEqual([$firstCalled->id, $secondCalled->id]);
})->group('F04', 'CA22');
