<?php

use App\Events\PickupRequestCalled;
use App\Events\PickupRequestDeparted;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;

/*
 * CA16 — Isolation multi-école stricte (écrit par le PO, non modifiable).
 * Un agent d'une école B ne peut JAMAIS agir sur une ressource d'une école A.
 * Réponse attendue : 404 strict (jamais 403, jamais 200).
 */

it('CA16 un surveillant école B ne peut pas appeler une classe de l\'école A', function () {
    $ecoleA = School::factory()->create();
    $demandeA = PickupRequest::factory()->for($ecoleA)->requested()->create();

    $ecoleB = School::factory()->create();
    $surveillantB = User::factory()->surveillant()->for($ecoleB)->create();

    Event::fake([PickupRequestCalled::class]);

    $this->actingAs($surveillantB, 'sanctum')
        ->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$ecoleA->id}/pickup-requests/{$demandeA->id}/call")
        ->assertNotFound()
        ->assertJsonMissing(['school_id' => $ecoleA->id]);

    expect($demandeA->fresh()->status)->toBe(PickupRequest::STATUS_REQUESTED);
    Event::assertNothingDispatched();
});

it('CA16 un surveillant école B ne peut pas libérer une demande de l\'école A', function () {
    $ecoleA = School::factory()->create();
    $demandeA = PickupRequest::factory()->for($ecoleA)->classNotified()->create();

    $ecoleB = School::factory()->create();
    $surveillantB = User::factory()->surveillant()->for($ecoleB)->create();

    Event::fake([PickupRequestDeparted::class]);

    $this->actingAs($surveillantB, 'sanctum')
        ->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$ecoleA->id}/pickup-requests/{$demandeA->id}/depart")
        ->assertNotFound();

    expect($demandeA->fresh()->status)->toBe(PickupRequest::STATUS_CLASS_NOTIFIED);
    Event::assertNothingDispatched();
});

it('CA16 un concierge école B ne peut pas voir la queue de l\'école A', function () {
    $ecoleA = School::factory()->create();
    $demandesA = PickupRequest::factory()->for($ecoleA)->requested()->count(3)->create();

    $ecoleB = School::factory()->create();
    $conciergeB = User::factory()->concierge()->for($ecoleB)->create();

    $response = $this->actingAs($conciergeB, 'sanctum')
        ->getJson("/api/v1/schools/{$ecoleA->id}/queue");

    $response->assertNotFound();

    foreach ($demandesA as $demande) {
        expect($response->getContent())->not->toContain($demande->id);
    }
});
