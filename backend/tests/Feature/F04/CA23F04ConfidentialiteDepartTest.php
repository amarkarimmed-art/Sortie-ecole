<?php

use App\Events\PickupRequestDeparted;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;

/*
 * CA23 — Confidentialité du payload Reverb de pickup.departed (écrit par le PO).
 * Champs AUTORISÉS : request_id, school_id, child_initial, departed_at.
 * PAS de class_name (l'enfant a quitté la classe).
 */

it('CA23 le payload pickup.departed ne contient aucune donnée personnelle', function () {
    Event::fake([PickupRequestDeparted::class]);

    $ecole = School::factory()->create();
    $enfant = Child::factory()->for($ecole)->create([
        'first_name' => 'Yasmine',
        'last_name' => 'ElFassi',
    ]);
    $demande = PickupRequest::factory()
        ->for($ecole)->for($enfant)
        ->classNotified()
        ->create();
    $surveillant = User::factory()->surveillant()->for($ecole)->create();

    $this->actingAs($surveillant, 'sanctum')
        ->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$ecole->id}/pickup-requests/{$demande->id}/depart")
        ->assertSuccessful();

    Event::assertDispatched(PickupRequestDeparted::class, function ($event) {
        $payload = $event->broadcastWith();
        $json = json_encode($payload);

        expect($json)
            ->not->toContain('Yasmine')
            ->not->toContain('ElFassi')
            ->not->toContain('+2126');

        expect($payload)->toHaveKeys(['request_id', 'school_id', 'child_initial', 'departed_at']);
        expect($payload)->not->toHaveKey('class_name');
        expect($payload['child_initial'])->toBe('Y.');

        return true;
    });
});
