<?php

declare(strict_types=1);

use App\Filament\Resources\UserResource;
use App\Models\Child;
use App\Models\School;
use App\Models\User;
use Filament\Facades\Filament;
use Illuminate\Support\Facades\Storage;

/**
 * 1. Un directeur de l'école A reçoit HTTP 404 (et jamais 403) lorsqu'il tente d'accéder
 * à la page d'édition d'un élève de l'école B (/admin/children/{childB}/edit) ou de le requêter via Child::find($childB->id).
 */
it('retourne HTTP 404 lorsqu\'un directeur tente d\'accéder à un élève d\'une autre école', function () {
    $schoolA = School::factory()->create(['name' => 'École Alpha']);
    $directorA = User::factory()->director()->create(['school_id' => $schoolA->id]);

    $schoolB = School::factory()->create(['name' => 'École Bêta']);
    $childB = Child::factory()->create(['school_id' => $schoolB->id]);

    $this->actingAs($directorA);

    // Requête directe Eloquent soumise au global scope BelongsToSchool
    expect(Child::find($childB->id))->toBeNull();

    // Accès HTTP à la ressource d'édition de l'école B
    $this->get("/admin/children/{$childB->id}/edit")
        ->assertNotFound();
});

/**
 * 2. Un directeur de l'école A ne voit que les parents et membres du personnel de son école A
 * (ceux de l'école B sont totalement invisibles dans UserResource::getEloquentQuery() et sur GET /admin/users).
 */
it('isole strictement les utilisateurs de l\'école A et rend invisibles ceux de l\'école B', function () {
    $schoolA = School::factory()->create(['name' => 'École A']);
    $directorA = User::factory()->director()->create(['school_id' => $schoolA->id]);
    $parentA = User::factory()->create([
        'school_id' => $schoolA->id,
        'name'      => 'Parent École A',
        'role'      => 'parent',
    ]);
    $surveillantA = User::factory()->surveillant()->create([
        'school_id' => $schoolA->id,
        'name'      => 'Surveillant École A',
    ]);

    $schoolB = School::factory()->create(['name' => 'École B']);
    $parentB = User::factory()->create([
        'school_id' => $schoolB->id,
        'name'      => 'Parent École B',
        'role'      => 'parent',
    ]);
    $surveillantB = User::factory()->surveillant()->create([
        'school_id' => $schoolB->id,
        'name'      => 'Surveillant École B',
    ]);

    $this->actingAs($directorA);

    // Vérification via la requête de ressource
    $queryIds = UserResource::getEloquentQuery()->pluck('id')->all();
    expect($queryIds)->toContain($parentA->id);
    expect($queryIds)->toContain($surveillantA->id);
    expect($queryIds)->not->toContain($parentB->id);
    expect($queryIds)->not->toContain($surveillantB->id);

    // Vérification via GET /admin/users
    $response = $this->get('/admin/users');
    $response->assertSuccessful();
    $response->assertSee('Parent École A');
    $response->assertSee('Surveillant École A');
    $response->assertDontSee('Parent École B');
    $response->assertDontSee('Surveillant École B');
});

/**
 * 3. Le logo et le nom affichés sur /admin correspondent à ceux de l'école du directeur connecté
 * (via Storage::disk('public')->url($schoolA->logo)), ne montrent jamais le branding du Super-Admin,
 * et ne fuitent jamais vers l'école B.
 */
it('affiche le nom et le logo de l\'école du directeur sur /admin sans fuite', function () {
    Storage::fake('public');
    $logoPath = 'school-logos/logo-alpha.png';
    Storage::disk('public')->put($logoPath, 'image-binary-data');

    $schoolA = School::factory()->create([
        'name' => 'École Al Amal Casablanca',
        'logo' => $logoPath,
    ]);
    $directorA = User::factory()->director()->create(['school_id' => $schoolA->id]);

    $schoolB = School::factory()->create([
        'name' => 'Autre École Secrète',
        'logo' => 'school-logos/logo-beta.png',
    ]);

    $this->actingAs($directorA);

    $response = $this->get('/admin');
    $response->assertSuccessful();

    // Nom de l'école A présent
    $response->assertSee('École Al Amal Casablanca');

    // Nom de l'école B absent
    $response->assertDontSee('Autre École Secrète');

    // Branding Super-Admin absent
    $response->assertDontSee('Super Admin');
    $response->assertDontSee('Réseau Super-Admin');

    // URL du logo de l'école A présente dans la page
    $expectedLogoUrl = Storage::disk('public')->url($schoolA->logo);
    $response->assertSee($expectedLogoUrl);
});

/**
 * 4. Un super_admin (role = 'super_admin', school_id = null) ainsi qu'un utilisateur sans school_id
 * ne peuvent pas ouvrir /admin (canAccessPanel(Filament::getPanel('admin')) === false et GET /admin retourne 403).
 */
it('bloque l\'accès à /admin pour un super_admin ou un compte sans school_id (403)', function () {
    $adminPanel = Filament::getPanel('admin');

    // Cas 1 : Compte Super Admin racine (sans school_id)
    $superAdmin = User::factory()->superAdmin()->create();
    expect($superAdmin->canAccessPanel($adminPanel))->toBeFalse();

    $this->actingAs($superAdmin)
        ->get('/admin')
        ->assertForbidden();

    // Cas 2 : Utilisateur admin sans school_id
    $userWithoutSchool = User::factory()->create([
        'school_id' => null,
        'role'      => 'admin',
    ]);
    expect($userWithoutSchool->canAccessPanel($adminPanel))->toBeFalse();

    $this->actingAs($userWithoutSchool)
        ->get('/admin')
        ->assertForbidden();
});
