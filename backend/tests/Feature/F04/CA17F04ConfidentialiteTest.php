<?php

use App\Events\PickupRequestCalled;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;

/*
 * CA17 — Confidentialité du payload Reverb de pickup.called (écrit par le PO).
 * Champs AUTORISÉS : request_id, school_id, class_name, child_initial.
 * Champs INTERDITS : nom complet, prénom complet, photo, GPS, téléphone.
 */

it('CA17 le payload pickup.called ne contient aucune donnée personnelle', function () {
    Event::fake([PickupRequestCalled::class]);

    $ecole = School::factory()->create();
    $enfant = Child::factory()->for($ecole)->create([
        'first_name' => 'Yasmine',
        'last_name' => 'ElFassi',
    ]);
    $demande = PickupRequest::factory()->for($ecole)->for($enfant)->requested()->create();
    $concierge = User::factory()->concierge()->for($ecole)->create();

    $this->actingAs($concierge, 'sanctum')
        ->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$ecole->id}/pickup-requests/{$demande->id}/call")
        ->assertSuccessful();

    Event::assertDispatched(PickupRequestCalled::class, function ($event) {
        $payload = $event->broadcastWith();
        $json = json_encode($payload);

        expect($json)
            ->not->toContain('Yasmine')
            ->not->toContain('ElFassi')
            ->not->toContain('+2126')
            ->not->toContain('photo')
            ->not->toContain('lat')
            ->not->toContain('lng');

        expect($payload)->toHaveKeys(['request_id', 'school_id', 'class_name', 'child_initial']);
        expect($payload['child_initial'])->toBe('Y.');

        return true;
    });
});
