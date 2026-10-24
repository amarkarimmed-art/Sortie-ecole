<?php

declare(strict_types=1);

use App\Filament\Pages\Auth\AdminLogin;
use App\Filament\SuperAdmin\Resources\SchoolResource\Pages\CreateSchool;
use App\Filament\SuperAdmin\Resources\SchoolResource\Pages\ListSchools;
use App\Filament\SuperAdmin\Resources\UserResource;
use App\Filament\SuperAdmin\Resources\UserResource\Pages\CreateUser;
use App\Models\Child;
use App\Models\HandoverLog;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\SchoolClass;
use App\Models\User;
use Filament\Facades\Filament;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Livewire\Livewire;

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

        // Justifié : Création du compte directeur initial dans le test
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

    // Justifié : Recherche sans global scope pour vérifier le directeur créé dans le test
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
    // Justifié : Création du compte directeur initial dans le test
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

/**
 * 8. Bout-en-bout : Création d'école via Livewire CreateSchool + Connexion du directeur via AdminLogin.
 */
it('crée une école et son directeur via Livewire puis permet au directeur de se connecter via AdminLogin', function () {
    Filament::setCurrentPanel(Filament::getPanel('super-admin'));
    $superAdmin = User::factory()->superAdmin()->create();
    $this->actingAs($superAdmin);

    Livewire::test(CreateSchool::class)
        ->fillForm([
            'name' => 'Groupe Scolaire Test',
            'director_email' => 'test.director@ecole.ma',
            'director_password' => '123456',
        ])
        ->call('create')
        ->assertHasNoFormErrors();

    // Justifié : Vérification sans global scope de l'existence du compte directeur créé
    $director = User::withoutGlobalScopes()
        ->where('email', 'test.director@ecole.ma')
        ->first();

    expect($director)->not->toBeNull();
    expect($director->role)->toBe('director');
    expect(Hash::check('123456', $director->password))->toBeTrue();

    // Déconnexion du Super-Admin et passage au panneau Admin
    auth()->logout();
    Filament::setCurrentPanel(Filament::getPanel('admin'));

    // S'assurer qu'un autre compte d'une autre école existe déjà en base
    $otherSchool = School::factory()->create(['name' => 'Autre École Existante']);
    User::factory()->director()->create([
        'school_id' => $otherSchool->id,
        'email' => 'autre.directeur@ecole.ma',
    ]);

    Livewire::test(AdminLogin::class)
        ->fillForm([
            'email' => 'test.director@ecole.ma',
            'password' => '123456',
        ])
        ->call('authenticate')
        ->assertHasNoFormErrors()
        ->assertRedirect('/admin');

    expect(auth()->check())->toBeTrue();
    expect(auth()->id())->toBe($director->id);
});

/**
 * 9. Suppression complète d'une école possédant directeur, classes, élève, demande et handover_logs.
 *    Vérifie également que le trigger handover_logs_ajout_seul reste actif pour les autres écoles (CA08HandoverLogImmutabilityTest).
 */
it('CA08HandoverLogImmutabilityTest : supprime entièrement une école et ses données associées sans bloquer sur le trigger handover_logs et maintient le trigger actif', function () {
    // 1. Création de deux écoles distinctes
    $schoolA = School::factory()->create(['name' => 'École Supprimée A']);
    $schoolB = School::factory()->create(['name' => 'École Préservée B']);

    // Données École A (à supprimer)
    // Justifié : Création du compte directeur initial de l'école A sans scope global
    $directorA = User::withoutGlobalScopes()->create([
        'school_id' => $schoolA->id,
        'name' => 'Directeur A',
        'email' => 'director.a@test.ma',
        'password' => 'secret123',
        'role' => 'director',
    ]);
    // Justifié : Création d'un parent de l'école A sans scope global
    $parentA = User::withoutGlobalScopes()->create([
        'school_id' => $schoolA->id,
        'name' => 'Parent A',
        'email' => 'parent.a@test.ma',
        'password' => 'secret123',
        'role' => 'parent',
    ]);
    // Justifié : Création d'un agent de l'école A sans scope global
    $agentA = User::withoutGlobalScopes()->create([
        'school_id' => $schoolA->id,
        'name' => 'Agent A',
        'email' => 'agent.a@test.ma',
        'password' => 'secret123',
        'role' => 'concierge',
    ]);

    $classA = SchoolClass::create([
        'school_id' => $schoolA->id,
        'name' => 'Classe CP A',
    ]);
    $childA = Child::create([
        'school_id' => $schoolA->id,
        'first_name' => 'Enfant',
        'last_name' => 'A',
        'class_name' => $classA->name,
    ]);
    $requestA = PickupRequest::factory()->create([
        'school_id' => $schoolA->id,
        'child_id' => $childA->id,
        'requested_by' => $parentA->id,
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);
    $logA = HandoverLog::create([
        'id' => (string) Str::uuid(),
        'school_id' => $schoolA->id,
        'pickup_request_id' => $requestA->id,
        'agent_id' => $agentA->id,
        'collector_type' => HandoverLog::COLLECTOR_PARENT,
        'parent_user_id' => $parentA->id,
        'idempotency_key' => (string) Str::uuid(),
        'created_at' => now(),
    ]);

    // Données École B (à préserver)
    // Justifié : Création du compte directeur initial de l'école B sans scope global
    $directorB = User::withoutGlobalScopes()->create([
        'school_id' => $schoolB->id,
        'name' => 'Directeur B',
        'email' => 'director.b@test.ma',
        'password' => 'secret123',
        'role' => 'director',
    ]);
    // Justifié : Création d'un parent de l'école B sans scope global
    $parentB = User::withoutGlobalScopes()->create([
        'school_id' => $schoolB->id,
        'name' => 'Parent B',
        'email' => 'parent.b@test.ma',
        'password' => 'secret123',
        'role' => 'parent',
    ]);
    // Justifié : Création d'un agent de l'école B sans scope global
    $agentB = User::withoutGlobalScopes()->create([
        'school_id' => $schoolB->id,
        'name' => 'Agent B',
        'email' => 'agent.b@test.ma',
        'password' => 'secret123',
        'role' => 'concierge',
    ]);
    $classB = SchoolClass::create([
        'school_id' => $schoolB->id,
        'name' => 'Classe CE1 B',
    ]);
    $childB = Child::create([
        'school_id' => $schoolB->id,
        'first_name' => 'Enfant',
        'last_name' => 'B',
        'class_name' => $classB->name,
    ]);
    $requestB = PickupRequest::factory()->create([
        'school_id' => $schoolB->id,
        'child_id' => $childB->id,
        'requested_by' => $parentB->id,
        'status' => PickupRequest::STATUS_HANDED_OVER,
    ]);
    $logB = HandoverLog::create([
        'id' => (string) Str::uuid(),
        'school_id' => $schoolB->id,
        'pickup_request_id' => $requestB->id,
        'agent_id' => $agentB->id,
        'collector_type' => HandoverLog::COLLECTOR_PARENT,
        'parent_user_id' => $parentB->id,
        'idempotency_key' => (string) Str::uuid(),
        'created_at' => now(),
    ]);

    // 2. Exécution de la suppression complète de l'école A
    $schoolA->deleteEntireSchool();

    // 3. Vérification que l'école A et toutes ses données associées ont disparu
    expect(School::find($schoolA->id))->toBeNull();
    // Justifié : Vérification de l'absence des utilisateurs sans scope global
    expect(User::withoutGlobalScopes()->where('school_id', $schoolA->id)->count())->toBe(0);
    expect(SchoolClass::where('school_id', $schoolA->id)->count())->toBe(0);
    expect(Child::where('school_id', $schoolA->id)->count())->toBe(0);
    expect(PickupRequest::where('school_id', $schoolA->id)->count())->toBe(0);
    expect(DB::table('handover_logs')->where('school_id', $schoolA->id)->count())->toBe(0);

    // 4. Vérification que l'école B et ses données sont intactes
    expect(School::find($schoolB->id))->not->toBeNull();
    // Justifié : Vérification de la présence des utilisateurs sans scope global
    expect(User::withoutGlobalScopes()->where('school_id', $schoolB->id)->count())->toBe(3);
    expect(DB::table('handover_logs')->where('school_id', $schoolB->id)->count())->toBe(1);

    // 5. Vérification que le trigger handover_logs_ajout_seul est toujours actif pour l'école B
    expect(function () use ($logB) {
        DB::transaction(function () use ($logB) {
            $logB->update(['collector_type' => HandoverLog::COLLECTOR_DAILY_CODE]);
        });
    })->toThrow(QueryException::class);

    expect(function () use ($logB) {
        DB::transaction(function () use ($logB) {
            $logB->delete();
        });
    })->toThrow(QueryException::class);
});

/**
 * 10. L'action Delete de ListSchools appelle deleteEntireSchool et supprime l'école.
 */
it('permet au super admin de supprimer une école via l\'action de table ListSchools', function () {
    Filament::setCurrentPanel(Filament::getPanel('super-admin'));
    $superAdmin = User::factory()->superAdmin()->create();
    $this->actingAs($superAdmin);

    $school = School::factory()->create(['name' => 'École À Supprimer Livewire']);
    // Justifié : Création d'un directeur sans scope global
    $director = User::withoutGlobalScopes()->create([
        'school_id' => $school->id,
        'name' => 'Directeur Livewire',
        'email' => 'director.livewire@test.ma',
        'password' => 'secret123',
        'role' => 'director',
    ]);

    Livewire::test(ListSchools::class)
        ->callTableAction('delete', $school);

    expect(School::find($school->id))->toBeNull();
    // Justifié : Vérification sans scope global
    expect(User::withoutGlobalScopes()->where('school_id', $school->id)->count())->toBe(0);
});
