<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

use App\Events\ArrivalSignaledEvent;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\PickupWindow;
use App\Models\School;
use App\Models\SchoolClass;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
    Carbon::setTestNow(Carbon::create(2026, 10, 5, 15, 30, 0, 'Africa/Casablanca'));
});

afterEach(function () {
    Carbon::setTestNow();
});

test('Exclusivité d\'une classe : une classe ne peut être assignée qu\'à un seul surveillant', function () {
    $school = School::factory()->create();
    $class = SchoolClass::create([
        'school_id' => $school->id,
        'name' => 'CP A',
    ]);

    $surveillantA = User::factory()->surveillant()->create(['school_id' => $school->id]);
    $surveillantB = User::factory()->surveillant()->create(['school_id' => $school->id]);

    $surveillantA->schoolClasses()->attach($class->id);
    expect($surveillantA->schoolClasses()->count())->toBe(1);

    expect(fn () => $surveillantB->schoolClasses()->attach($class->id))
        ->toThrow(UniqueConstraintViolationException::class);
});

test('Isolation GET /queue : le surveillant ne voit que ses classes assignées avec child_name, class_name et parent_name', function () {
    $school = School::factory()->create();

    $classCE1 = SchoolClass::create(['school_id' => $school->id, 'name' => 'CE1 A']);
    $classCM2 = SchoolClass::create(['school_id' => $school->id, 'name' => 'CM2 B']);

    $parentA = User::factory()->create(['school_id' => $school->id, 'role' => 'parent', 'name' => 'Fatima Zahra']);
    $childA = Child::factory()->create(['school_id' => $school->id, 'first_name' => 'Yassine', 'last_name' => 'El Amrani', 'class_name' => 'CE1 A']);
    $parentA->children()->attach($childA->id, ['relationship' => 'parent']);

    $parentB = User::factory()->create(['school_id' => $school->id, 'role' => 'parent', 'name' => 'Omar Bennani']);
    $childB = Child::factory()->create(['school_id' => $school->id, 'first_name' => 'Kenza', 'last_name' => 'Bennani', 'class_name' => 'CM2 B']);
    $parentB->children()->attach($childB->id, ['relationship' => 'parent']);

    $reqA = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $childA->id,
        'requested_by' => $parentA->id,
    ]);

    $reqB = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $childB->id,
        'requested_by' => $parentB->id,
    ]);

    $surveillantA = User::factory()->surveillant()->create(['school_id' => $school->id]);
    $surveillantA->schoolClasses()->attach($classCE1->id);

    Sanctum::actingAs($surveillantA);
    $res = $this->getJson("/api/v1/schools/{$school->id}/queue");
    $res->assertStatus(200);

    $items = $res->json();
    expect($items)->toHaveCount(1);
    expect($items[0]['id'])->toBe((string) $reqA->id);
    expect($items[0]['request_id'])->toBe((string) $reqA->id);
    expect($items[0]['child_name'])->toBe('Yassine El Amrani');
    expect($items[0]['class_name'])->toBe('CE1 A');
    expect($items[0]['parent_name'])->toBe('Fatima Zahra');
    expect($items[0]['parent_user_id'])->toBe((string) $parentA->id);
    expect($items[0]['status'])->toBe('requested');
});

test('Flux complet en 2 étapes par le Surveillant : depart -> on_the_way puis handover -> handed_over', function () {
    $school = School::factory()->create();
    $class = SchoolClass::create(['school_id' => $school->id, 'name' => '6eme A']);

    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent', 'name' => 'Karim Idrissi']);
    $child = Child::factory()->create(['school_id' => $school->id, 'first_name' => 'Sami', 'last_name' => 'Idrissi', 'class_name' => '6eme A']);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    $request = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
        'requested_by' => $parent->id,
    ]);

    $surveillant = User::factory()->surveillant()->create(['school_id' => $school->id]);
    $surveillant->schoolClasses()->attach($class->id);

    Sanctum::actingAs($surveillant);

    // Étape 1 : depart -> 200, status on_the_way
    $departRes = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/depart");
    $departRes->assertStatus(200);
    $departRes->assertJson([
        'id' => (string) $request->id,
        'status' => 'on_the_way',
    ]);

    // Demande reste visible dans GET /queue avec status on_the_way
    $queueRes = $this->getJson("/api/v1/schools/{$school->id}/queue");
    $queueRes->assertStatus(200);
    $queueItems = $queueRes->json();
    expect($queueItems)->toHaveCount(1);
    expect($queueItems[0]['id'])->toBe((string) $request->id);
    expect($queueItems[0]['status'])->toBe('on_the_way');

    // Étape 2 : handover -> 201, status handed_over, trace dans handover_logs
    $handoverRes = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$request->id}/handover", [
            'collector_type' => 'parent',
            'parent_user_id' => (string) $parent->id,
        ]);
    $handoverRes->assertStatus(201);
    expect($handoverRes->json('pickup_request_id'))->toBe((string) $request->id);
    expect($request->fresh()->status)->toBe(PickupRequest::STATUS_HANDED_OVER);

    // Trace immuable créée dans handover_logs
    $this->assertDatabaseHas('handover_logs', [
        'school_id' => $school->id,
        'pickup_request_id' => $request->id,
        'agent_id' => $surveillant->id,
        'parent_user_id' => $parent->id,
    ]);

    // La demande disparaît de GET /queue
    $queueAfter = $this->getJson("/api/v1/schools/{$school->id}/queue");
    $queueAfter->assertStatus(200);
    expect($queueAfter->json())->toBeEmpty();
});

test('Sécurité inter-classes : le Surveillant B reçoit HTTP 403 s\'il tente /depart ou /handover sur une classe non assignée', function () {
    $school = School::factory()->create();

    $classA = SchoolClass::create(['school_id' => $school->id, 'name' => 'Classe A']);
    $classB = SchoolClass::create(['school_id' => $school->id, 'name' => 'Classe B']);

    $childA = Child::factory()->create(['school_id' => $school->id, 'class_name' => 'Classe A']);
    $requestA = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $childA->id,
    ]);

    $surveillantB = User::factory()->surveillant()->create(['school_id' => $school->id]);
    $surveillantB->schoolClasses()->attach($classB->id);

    Sanctum::actingAs($surveillantB);

    // Tentative /depart sur l'élève de la classe A -> 403
    $departRes = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$requestA->id}/depart");
    $departRes->assertStatus(403);

    // Tentative /handover sur l'élève de la classe A -> 403
    $handoverRes = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$requestA->id}/handover", [
            'collector_type' => 'parent',
        ]);
    $handoverRes->assertStatus(403);
});

test('Flux complet arrivée -> depart avec request_id ou multi-clés et double-clic idempotent', function () {
    Event::fake([ArrivalSignaledEvent::class]);

    $school = School::factory()->create();

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '15:00:00',
        'end_time' => '16:00:00',
        'is_ramadan' => false,
    ]);

    $parent = User::factory()->create([
        'school_id' => $school->id,
        'role' => 'parent',
    ]);

    $child = Child::factory()->create([
        'school_id' => $school->id,
        'class_name' => 'CE1 A',
    ]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    $surveillant = User::factory()->surveillant()->create([
        'school_id' => $school->id,
    ]);

    // 1. Signalement d'arrivée par le parent
    Sanctum::actingAs($parent);
    $arrivalRes = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/arrivals", [
            'child_ids' => [$child->id],
            'in_radius' => true,
            'distance_meters' => 30,
        ]);
    $arrivalRes->assertStatus(201);
    $arrivalId = $arrivalRes->json('id');

    // 2. Vérification que l'event Reverb est émis avec request_id
    Event::assertDispatched(ArrivalSignaledEvent::class, function ($event) use ($arrivalId) {
        $data = $event->broadcastWith();
        return $data['arrival_id'] === $arrivalId && ! empty($data['request_id']);
    });

    // 3. Récupération de la demande active
    $request = PickupRequest::where('school_id', $school->id)
        ->where('child_id', $child->id)
        ->latest('created_at')
        ->first();
    expect($request)->not->toBeNull();
    $requestId = (string) $request->id;

    // 4. Premier clic "Parti" par le surveillant -> 200, statut on_the_way
    Sanctum::actingAs($surveillant);
    $departRes1 = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$requestId}/depart");
    $departRes1->assertStatus(200);
    $departRes1->assertJson([
        'id' => $requestId,
        'status' => 'on_the_way',
    ]);

    // 5. Deuxième clic "Parti" (double-clic) -> 200 idempotent (jamais 404 ni 422)
    $departRes2 = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$requestId}/depart");
    $departRes2->assertStatus(200);
    $departRes2->assertJson([
        'id' => $requestId,
        'status' => 'on_the_way',
    ]);

    // 6. Clic en passant l'arrival_id au lieu du request_id (résolution multi-clés) -> 200
    $departRes3 = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$arrivalId}/depart");
    $departRes3->assertStatus(200);
    $departRes3->assertJson([
        'id' => $requestId,
        'status' => 'on_the_way',
    ]);

    // 7. Clic en passant le child_id au lieu du request_id -> 200
    $departRes4 = $this->withHeader('Idempotency-Key', (string) Str::uuid())
        ->postJson("/api/v1/schools/{$school->id}/pickup-requests/{$child->id}/depart");
    $departRes4->assertStatus(200);
    $departRes4->assertJson([
        'id' => $requestId,
        'status' => 'on_the_way',
    ]);
});

test('Les vues Blade compilent dans /tmp/sortie_ecole_views_* sans toucher à /var/www/storage/framework/views', function () {
    $uid = function_exists('posix_geteuid') ? posix_geteuid() : getmyuid();
    $expectedPath = sys_get_temp_dir() . '/sortie_ecole_views_' . $uid;

    expect(config('view.compiled'))->toBe($expectedPath);

    // Requêtes sur /super-admin/login et /admin/login
    $resSuperAdmin = $this->get('/super-admin/login');
    expect($resSuperAdmin->status())->toBeIn([200, 302]);

    $resAdmin = $this->get('/admin/login');
    expect($resAdmin->status())->toBeIn([200, 302]);

    // Vérifier que le dossier compilé existe dans /tmp
    expect(is_dir($expectedPath))->toBeTrue();
});
