<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Filament\Resources\UserResource;
use App\Filament\Resources\UserResource\Pages\CreateUser;
use App\Models\Child;
use App\Models\School;
use App\Models\User;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
    RateLimiter::clear('login:*');
});

test('Test 1 : Connexion parent avec login et mot de passe (succès 200 et échec 401 générique)', function () {
    $school = School::factory()->create([
        'name' => 'École Lumière',
        'logo' => 'school-logos/lumiere.png',
        'is_suspended' => false,
    ]);

    $parent = User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'parent.test@lumiere',
        'password'  => 'motdepasse123',
        'role'      => 'parent',
        'name'      => 'Fatima Zahra',
    ]);

    $child = Child::factory()->create([
        'school_id'  => $school->id,
        'first_name' => 'Aya',
        'last_name'  => 'Zahra',
    ]);
    $child->parents()->attach($parent->id, ['relationship' => 'parent']);

    // Connexion réussie
    $response = $this->postJson('/api/login', [
        'login'    => 'parent.test@lumiere',
        'password' => 'motdepasse123',
    ]);

    $response->assertStatus(200)
        ->assertJsonStructure([
            'token',
            'user' => [
                'id',
                'name',
                'login',
                'role',
                'school_id',
                'school_name',
                'school_logo',
                'children',
            ],
        ]);

    expect($response->json('user.login'))->toBe('parent.test@lumiere');
    expect($response->json('user.school_name'))->toBe('École Lumière');
    expect($response->json('user.children'))->toHaveCount(1);
    expect($response->json('user.children.0.first_name'))->toBe('Aya');

    // Échec mauvais mot de passe -> 401 générique
    $responseBadPass = $this->postJson('/api/login', [
        'login'    => 'parent.test@lumiere',
        'password' => 'wrongpassword',
    ]);

    $responseBadPass->assertStatus(401)
        ->assertJson(['message' => 'Identifiants incorrects.']);

    // Échec login inexistant -> 401 même message générique
    $responseInconnu = $this->postJson('/api/login', [
        'login'    => 'inconnu@alamal',
        'password' => 'password123',
    ]);

    $responseInconnu->assertStatus(401)
        ->assertJson(['message' => 'Identifiants incorrects.']);
});

test('Test 2 : Séparation stricte des rôles par application (parent vs ecole)', function () {
    $school = School::factory()->create(['is_suspended' => false]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'parent@alamal',
        'password'  => 'password123',
        'role'      => 'parent',
    ]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'surveillant@alamal',
        'password'  => 'password123',
        'role'      => 'surveillant',
    ]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'concierge@alamal',
        'password'  => 'password123',
        'role'      => 'concierge',
    ]);

    // Parent refusé sur app_type='ecole'
    $this->postJson('/api/login', [
        'login'    => 'parent@alamal',
        'password' => 'password123',
        'app_type' => 'ecole',
    ])->assertStatus(403)
      ->assertJson(['message' => 'Accès réservé au personnel de surveillance et d\'accueil.']);

    // Surveillant refusé sur app_type='parent'
    $this->postJson('/api/login', [
        'login'    => 'surveillant@alamal',
        'password' => 'password123',
        'app_type' => 'parent',
    ])->assertStatus(403)
      ->assertJson(['message' => 'Accès réservé aux parents.']);

    // Surveillant accepté sur app_type='ecole'
    $this->postJson('/api/login', [
        'login'    => 'surveillant@alamal',
        'password' => 'password123',
        'app_type' => 'ecole',
    ])->assertStatus(200);

    // Concierge accepté sur app_type='ecole'
    $this->postJson('/api/login', [
        'login'    => 'concierge@alamal',
        'password' => 'password123',
        'app_type' => 'ecole',
    ])->assertStatus(200);
});

test('Test 3 : Director, admin et super_admin refusés systématiquement sur POST /api/login', function () {
    $school = School::factory()->create(['is_suspended' => false]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'director.test@alamal',
        'password'  => 'password123',
        'role'      => 'director',
    ]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'admin.test@alamal',
        'password'  => 'password123',
        'role'      => 'admin',
    ]);

    User::factory()->create([
        'school_id' => null,
        'email'     => 'superadmin.test@sortie',
        'password'  => 'password123',
        'role'      => 'super_admin',
    ]);

    foreach (['director.test@alamal', 'admin.test@alamal', 'superadmin.test@sortie'] as $login) {
        $this->postJson('/api/login', [
            'login'    => $login,
            'password' => 'password123',
        ])->assertStatus(403)
          ->assertJson(['message' => 'Accès non autorisé sur cette application.']);
    }
});

test('Test 4 : Throttle bloque la 6e tentative en moins d\'une minute avec 429', function () {
    $school = School::factory()->create(['is_suspended' => false]);
    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'victim@alamal',
        'password'  => 'password123',
        'role'      => 'parent',
    ]);

    // 5 tentatives erronées (401)
    for ($i = 0; $i < 5; $i++) {
        $this->postJson('/api/login', [
            'login'    => 'victim@alamal',
            'password' => 'wrong',
        ])->assertStatus(401);
    }

    // 6e tentative -> 429
    $this->postJson('/api/login', [
        'login'    => 'victim@alamal',
        'password' => 'wrong',
    ])->assertStatus(429)
      ->assertJson(['message' => 'Trop de tentatives, réessayez dans une minute.']);
});

test('Test 5 : Compte d\'une école suspendue est refusé sur POST /api/login (403)', function () {
    $school = School::factory()->create(['is_suspended' => true]);

    User::factory()->create([
        'school_id' => $school->id,
        'email'     => 'parent.suspendu@alamal',
        'password'  => 'password123',
        'role'      => 'parent',
    ]);

    $this->postJson('/api/login', [
        'login'    => 'parent.suspendu@alamal',
        'password' => 'password123',
    ])->assertStatus(403)
      ->assertJson(['message' => 'École suspendue, contactez l\'administration.']);
});

test('Test 6 : L\'admin/directeur de l\'école A crée un parent dans /admin et ne peut pas créer de rôle staff/admin', function () {
    $schoolA = School::factory()->create(['name' => 'École A', 'is_suspended' => false]);
    $directorA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role'      => 'director',
    ]);

    $this->actingAs($directorA);

    // 1. Vérifier que le formulaire ne propose aucun sélecteur school_id et ne propose que parent, surveillant, concierge
    $dummy = new class implements HasForms {
        use InteractsWithForms;
    };
    $form = UserResource::form(Form::make($dummy));
    $fields = array_keys($form->getFlatFields());

    expect($fields)->not->toContain('school_id');
    expect($fields)->toContain('name');
    expect($fields)->toContain('email');
    expect($fields)->toContain('password');
    expect($fields)->toContain('role');

    // 2. Tester mutateFormDataBeforeCreate de CreateUser
    $page = new CreateUser();
    $reflection = new \ReflectionMethod(CreateUser::class, 'mutateFormDataBeforeCreate');
    $reflection->setAccessible(true);

    $mutated = $reflection->invoke($page, [
        'name'     => 'Nouveau Parent',
        'email'    => 'parent.nouveau@ecolea',
        'password' => 'sortie2026',
        'role'     => 'parent',
    ]);

    expect($mutated['school_id'])->toBe($schoolA->id);
    expect($mutated['role'])->toBe('parent');

    // 3. Tentative de forcer un rôle director, admin ou super_admin -> ValidationException
    foreach (['director', 'admin', 'super_admin'] as $forbiddenRole) {
        try {
            $reflection->invoke($page, [
                'name'     => 'Hacker',
                'email'    => 'hacker@ecolea',
                'password' => 'sortie2026',
                'role'     => $forbiddenRole,
            ]);
            $this->fail("Le rôle {$forbiddenRole} aurait dû lever une ValidationException");
        } catch (ValidationException $e) {
            expect($e->errors())->toHaveKey('role');
        }
    }
});

test('Test 7 : Cloisonnement school_id strict : HTTP 404 sur enfant d\'une autre école', function () {
    $schoolA = School::factory()->create(['is_suspended' => false]);
    $schoolB = School::factory()->create(['is_suspended' => false]);

    $parentA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role'      => 'parent',
    ]);

    $childB = Child::factory()->create([
        'school_id' => $schoolB->id,
    ]);

    $this->actingAs($parentA);

    // Requêter Child sans global scope bypass retourne null (404 au niveau Eloquent)
    $foundChild = Child::find($childB->id);
    expect($foundChild)->toBeNull();
});

test('Test 8 : Anciennes routes OTP retournent 404 et logout révoque le token Sanctum', function () {
    $this->postJson('/api/v1/auth/login', ['phone' => '+212600000000'])->assertStatus(404);
    $this->postJson('/api/v1/auth/verify', ['phone' => '+212600000000', 'code' => '123456'])->assertStatus(404);

    $school = School::factory()->create(['is_suspended' => false]);
    $user = User::factory()->create([
        'school_id' => $school->id,
        'role'      => 'parent',
        'email'     => 'logout.user@alamal',
        'password'  => 'password',
    ]);

    $loginRes = $this->postJson('/api/login', [
        'login'    => 'logout.user@alamal',
        'password' => 'password',
    ])->assertStatus(200);

    $token = $loginRes->json('token');
    expect(PersonalAccessToken::count())->toBeGreaterThan(0);

    // GET /api/me avec le token fonctionne
    $this->withToken($token)->getJson('/api/me')->assertStatus(200);

    // POST /api/logout révoque le token
    $this->withToken($token)->postJson('/api/logout')
        ->assertStatus(200)
        ->assertJson(['message' => 'Déconnexion réussie.']);

    // Le token a bien été supprimé en base de données
    expect(PersonalAccessToken::count())->toBe(0);

    // Réinitialiser les guards pour forcer une nouvelle authentification par token
    $this->app['auth']->forgetGuards();

    // Le token révoqué ne peut plus accéder à /api/me
    $this->withToken($token)->getJson('/api/me')->assertStatus(401);
});

test('Test 9 : Commande accounts:generate-logins génère des logins uniques et le fichier CSV', function () {
    $school = School::factory()->create(['name' => 'École Oasis']);

    // Créer des comptes sans email
    $parent1 = User::withoutGlobalScopes()->create([
        'school_id' => $school->id,
        'name'      => 'Karim Ben',
        'role'      => 'parent',
        'email'     => null,
    ]);

    $parent2 = User::withoutGlobalScopes()->create([
        'school_id' => $school->id,
        'name'      => 'Karim Ben',
        'role'      => 'parent',
        'email'     => '',
    ]);

    $csvFile = storage_path('app/test_generated_logins.csv');
    if (File::exists($csvFile)) {
        File::delete($csvFile);
    }

    $exitCode = Artisan::call('accounts:generate-logins', [
        '--output' => $csvFile,
    ]);

    expect($exitCode)->toBe(0);
    expect(File::exists($csvFile))->toBeTrue();

    $parent1->refresh();
    $parent2->refresh();

    expect($parent1->email)->not->toBeNull();
    expect($parent2->email)->not->toBeNull();
    // Les logins doivent être distincts et non vides
    expect($parent1->email)->not->toBe($parent2->email);
    expect($parent1->password)->not->toBeNull();

    // Nettoyage
    File::delete($csvFile);
});

test('Test 10 : Un parent peut s\'authentifier sur son canal privé parent mais est refusé sur le canal queue', function () {
    $school = School::factory()->create();
    $parent = User::factory()->create([
        'school_id' => $school->id,
        'role'      => 'parent',
    ]);

    // Autorisé sur son propre canal privé parent
    $this->actingAs($parent, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$school->id}.parent.{$parent->id}",
            'socket_id'    => '1234.5678',
        ])
        ->assertSuccessful();

    // Refusé sur le canal queue de l'école (réservé aux agents / surveillants)
    $this->actingAs($parent, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$school->id}.queue",
            'socket_id'    => '1234.5678',
        ])
        ->assertForbidden();

    // Refusé sur le canal d'un autre parent
    $otherParent = User::factory()->create([
        'school_id' => $school->id,
        'role'      => 'parent',
    ]);

    $this->actingAs($parent, 'sanctum')
        ->postJson('/broadcasting/auth', [
            'channel_name' => "private-school.{$school->id}.parent.{$otherParent->id}",
            'socket_id'    => '1234.5678',
        ])
        ->assertForbidden();
});
