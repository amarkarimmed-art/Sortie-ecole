<?php

declare(strict_types=1);

use App\Filament\SuperAdmin\Resources\UserResource;
use App\Filament\SuperAdmin\Resources\UserResource\Pages\CreateUser;
use App\Models\School;
use App\Models\User;
use Filament\Facades\Filament;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * 1. Création d'une école + directeur avec seulement nom de l'école, login et mot de passe
 *    (et vérification du rollback DB::transaction : rien n'est créé si le directeur échoue, par ex. login en doublon).
 */
it('crée une école et son directeur de façon atomique et effectue un rollback en cas d\'échec', function () {
    $superAdmin = User::factory()->superAdmin()->create();
    $this->actingAs($superAdmin);

    $schoolName = 'École Pilote Casablanca';
    $login = 'directeur.pilote@ecole-test.ma';
    $password = 'secret123';

    // 1.a. Création réussie via transaction
    DB::transaction(function () use ($schoolName, $login, $password) {
        $school = School::create([
            'name' => $schoolName,
            'is_suspended' => false,
        ]);

        User::withoutGlobalScopes()->create([
            'school_id' => $school->id,
            'name' => $school->name,
            'email' => $login,
            'password' => $password,
            'role' => 'director',
        ]);
    });

    $school = School::where('name', $schoolName)->first();
    expect($school)->not->toBeNull();
    expect($school->is_suspended)->toBeFalse();

    $director = User::withoutGlobalScopes()->where('email', $login)->first();
    expect($director)->not->toBeNull();
    expect($director->role)->toBe('director');
    expect($director->name)->toBe($schoolName);
    expect($director->school_id)->toBe($school->id);
    expect(Hash::check($password, $director->password))->toBeTrue();

    // 1.b. Vérification du rollback DB::transaction si le directeur échoue (login dupliqué)
    $failedSchoolName = 'École Qui Doit Être Rollback';
    try {
        DB::transaction(function () use ($failedSchoolName, $login) {
            $school = School::create([
                'name' => $failedSchoolName,
                'is_suspended' => false,
            ]);

            // Email dupliqué provoquant une violation d'unicité
            User::withoutGlobalScopes()->create([
                'school_id' => $school->id,
                'name' => $school->name,
                'email' => $login,
                'password' => 'pass123',
                'role' => 'director',
            ]);
        });
    } catch (\Throwable $e) {
        // Exception attendue
    }

    expect(School::where('name', $failedSchoolName)->exists())->toBeFalse();
});

/**
 * 2. Le directeur créé se connecte directement avec le mot de passe créé et accède à /admin.
 */
it('permet au directeur créé de se connecter avec son mot de passe et d\'accéder à /admin', function () {
    $school = School::create([
        'name' => 'École Al Amal Test',
        'is_suspended' => false,
    ]);

    $password = 'directeurSecret123';
    $director = User::withoutGlobalScopes()->create([
        'school_id' => $school->id,
        'name' => $school->name,
        'email' => 'direction@alamal-test.ma',
        'password' => $password,
        'role' => 'director',
    ]);

    expect(Hash::check($password, $director->password))->toBeTrue();

    $this->actingAs($director)
        ->get('/admin')
        ->assertSuccessful();
});

/**
 * 3. Le formulaire Directeurs (UserResource) n'a ni role, ni name, ni phone, et la liste ne retourne que role = 'director'.
 */
it('ne contient ni role ni name ni phone dans le formulaire et ne liste que role director', function () {
    $dummy = new class implements HasForms {
        use InteractsWithForms;
    };
    $form = UserResource::form(Form::make($dummy));
    $fields = array_keys($form->getFlatFields());

    expect($fields)->not->toContain('role');
    expect($fields)->not->toContain('name');
    expect($fields)->not->toContain('phone');
    expect($fields)->toContain('school_id');
    expect($fields)->toContain('email');
    expect($fields)->toContain('password');

    // Vérification que getEloquentQuery n'isole que role = director
    $school = School::factory()->create();
    $director = User::factory()->director()->create(['school_id' => $school->id]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $superAdmin = User::factory()->superAdmin()->create();
    $surveillant = User::factory()->surveillant()->create(['school_id' => $school->id]);

    $queryIds = UserResource::getEloquentQuery()->pluck('id')->all();

    expect($queryIds)->toContain($director->id);
    expect($queryIds)->not->toContain($parent->id);
    expect($queryIds)->not->toContain($superAdmin->id);
    expect($queryIds)->not->toContain($surveillant->id);
});

/**
 * 4. Le super admin ne peut pas créer de parent (le rôle est forcé à director).
 */
it('force le rôle à director lors de la création d\'un compte utilisateur par le super admin', function () {
    $school = School::factory()->create(['name' => 'École Test Forçage']);

    $page = new CreateUser();
    $reflection = new \ReflectionMethod(CreateUser::class, 'mutateFormDataBeforeCreate');
    $reflection->setAccessible(true);

    $mutatedData = $reflection->invoke($page, [
        'school_id' => $school->id,
        'email' => 'test.role.force@ecole.ma',
        'password' => 'secret123',
        'role' => 'parent', // Tentative de définir parent
    ]);

    expect($mutatedData['role'])->toBe('director');
    expect($mutatedData['phone'])->toBeNull();
    expect($mutatedData['name'])->toBe($school->name);
});

/**
 * 5. Un directeur ne peut pas ouvrir /super-admin (HTTP 403 / canAccessPanel false).
 */
it('interdit l\'accès à /super-admin pour un directeur (403 et canAccessPanel false)', function () {
    $school = School::factory()->create();
    $director = User::factory()->director()->create(['school_id' => $school->id]);

    $superAdminPanel = Filament::getPanel('super-admin');
    expect($director->canAccessPanel($superAdminPanel))->toBeFalse();

    $this->actingAs($director)
        ->get('/super-admin')
        ->assertForbidden();
});

/**
 * 6. Une école suspendue (is_suspended = true) bloque l'accès de son directeur à /admin.
 */
it('bloque l\'accès de son directeur à /admin si l\'école est suspendue', function () {
    $suspendedSchool = School::factory()->create(['is_suspended' => true]);
    $director = User::factory()->director()->create(['school_id' => $suspendedSchool->id]);

    $adminPanel = Filament::getPanel('admin');
    expect($director->canAccessPanel($adminPanel))->toBeFalse();

    $this->actingAs($director)
        ->get('/admin')
        ->assertForbidden();

    // Vérification que si l'école est active, le directeur accède bien à /admin
    $activeSchool = School::factory()->create(['is_suspended' => false]);
    $activeDirector = User::factory()->director()->create(['school_id' => $activeSchool->id]);

    expect($activeDirector->canAccessPanel($adminPanel))->toBeTrue();

    $this->actingAs($activeDirector)
        ->get('/admin')
        ->assertSuccessful();
});

/**
 * 7. Les pages du super admin (/super-admin, /super-admin/schools, /super-admin/schools/create, /super-admin/users, /super-admin/users/create) s'affichent sans erreur (HTTP 200).
 */
it('affiche les pages principales du Super-Admin sans erreur (HTTP 200)', function () {
    $superAdmin = User::factory()->superAdmin()->create();

    $this->actingAs($superAdmin)
        ->get('/super-admin')
        ->assertSuccessful();

    $this->actingAs($superAdmin)
        ->get('/super-admin/schools')
        ->assertSuccessful();

    $this->actingAs($superAdmin)
        ->get('/super-admin/schools/create')
        ->assertSuccessful();

    $this->actingAs($superAdmin)
        ->get('/super-admin/users')
        ->assertSuccessful();

    $this->actingAs($superAdmin)
        ->get('/super-admin/users/create')
        ->assertSuccessful();
});
