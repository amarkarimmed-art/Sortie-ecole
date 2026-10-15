<?php

declare(strict_types=1);

use App\Models\School;
use App\Models\User;

/*
 * CA21 — un parent ne peut PAS s'abonner au canal Reverb de l'école.
 * Le canal school.{id}.queue est réservé aux rôles concierge,
 * surveillant et director de la même école.
 */

// 1. Parent refuse sur le canal de sa propre école
it('CA21 un parent ne peut pas s\'abonner au canal de son école', function () {
    $ecole = School::factory()->create();
    $parent = User::factory()->for($ecole)->create(['role' => 'parent']);

    $this->actingAs($parent, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$ecole->id}.queue",
            'socket_id' => '1234.5678',
        ])
        ->assertForbidden();
});

// 2. Concierge autorisé sur sa propre école
it('CA21 un concierge peut s\'abonner au canal de son école', function () {
    $ecole = School::factory()->create();
    $concierge = User::factory()->concierge()->for($ecole)->create();

    $this->actingAs($concierge, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$ecole->id}.queue",
            'socket_id' => '1234.5678',
        ])
        ->assertSuccessful();
});

// 3. Concierge école B refuse sur canal école A
it('CA21 un concierge d\'une autre école ne peut pas s\'abonner', function () {
    $ecoleA = School::factory()->create();
    $ecoleB = School::factory()->create();
    $conciergeB = User::factory()->concierge()->for($ecoleB)->create();

    $this->actingAs($conciergeB, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$ecoleA->id}.queue",
            'socket_id' => '1234.5678',
        ])
        ->assertForbidden();
});

// 4. Surveillant autorisé (nouvelle règle F04)
it('CA21 un surveillant peut s\'abonner au canal de son école', function () {
    $ecole = School::factory()->create();
    $surveillant = User::factory()->surveillant()->for($ecole)->create();

    $this->actingAs($surveillant, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$ecole->id}.queue",
            'socket_id' => '1234.5678',
        ])
        ->assertSuccessful();
});
