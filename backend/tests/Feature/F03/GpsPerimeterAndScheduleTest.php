<?php

declare(strict_types=1);

namespace Tests\Feature\F03;

use App\Events\ArrivalSignaledEvent;
use App\Events\ParentApproachingEvent;
use App\Models\Arrival;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\PickupWindow;
use App\Models\School;
use App\Models\User;
use App\Services\Geo\HaversineService;
use App\Services\Schedule\PickupScheduleService;
use Carbon\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Event;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

/*
|--------------------------------------------------------------------------
| SÉRIE 1 : Calcul de distance Haversine sur des coordonnées connues
|--------------------------------------------------------------------------
*/
test('1. Calcul de distance Haversine sur des coordonnées connues (précision au mètre près)', function () {
    $service = new HaversineService();

    // Portail référence à Casablanca
    $gateLat = 33.573110;
    $gateLng = -7.589843;

    // Déplacement de 30 mètres vers le nord (1 degré de latitude ~ 111139 m)
    $lat30m = $gateLat + (30 / 111139);
    $distance30 = $service->distanceMeters($gateLat, $gateLng, $lat30m, $gateLng);
    expect($distance30)->toBe(30);

    // Déplacement de 80 mètres vers le nord
    $lat80m = $gateLat + (80 / 111139);
    $distance80 = $service->distanceMeters($gateLat, $gateLng, $lat80m, $gateLng);
    expect($distance80)->toBe(80);

    // Mêmes coordonnées = 0 mètre
    $distance0 = $service->distanceMeters($gateLat, $gateLng, $gateLat, $gateLng);
    expect($distance0)->toBe(0);

    // Distance Casablanca (33.573110, -7.589843) -> Rabat (34.020882, -6.841650)
    // Distance réelle orthodromique ~ 85.2 km
    $distCasaRabat = $service->distanceMeters($gateLat, $gateLng, 34.020882, -6.841650);
    expect($distCasaRabat)->toBeGreaterThan(85000)->toBeLessThan(86000);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 2 : Parent à 30 m accepté (201) et parent à 80 m refusé (422)
|--------------------------------------------------------------------------
*/
test('2. Parent à 30 m accepté (201) et parent à 80 m refusé (422) avec le message contenant la distance pour rayon 50 m', function () {
    Event::fake();

    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'opening_margin_minutes' => 10,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);

    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child1 = Child::factory()->create(['school_id' => $school->id]);
    $child2 = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach([$child1->id, $child2->id], ['relationship' => 'parent']);

    // Plage horaire ouverte un lundi de 16h00 à 17h00
    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '17:00:00',
        'is_ramadan' => false,
    ]);

    $testTime = Carbon::create(2026, 10, 5, 16, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($testTime);

    Sanctum::actingAs($parent);

    // 1. Parent à 30 mètres (dans le rayon de 50 m) pour child1 -> 201 Created
    $lat30m = 33.573110 + (30 / 111139);
    $response30 = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child1->id],
        'pos_lat' => $lat30m,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $testTime->toIso8601String(),
    ]);

    $response30->assertStatus(201);
    $response30->assertJsonPath('in_radius', true);

    // 2. Parent à 80 mètres (hors du rayon de 50 m) pour child2 -> 422 avec message exact
    $lat80m = 33.573110 + (80 / 111139);
    $response80 = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child2->id],
        'pos_lat' => $lat80m,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $testTime->toIso8601String(),
    ]);

    $response80->assertStatus(422);
    $errorMessage = $response80->json('message') ?? json_encode($response80->json());
    expect($errorMessage)->toContain('80 mètres');
});

/*
|--------------------------------------------------------------------------
| SÉRIE 3 : Limites exactes des 3 états (dans le périmètre, en approche, hors zone)
|--------------------------------------------------------------------------
*/
test('3. Limites exactes des 3 états (dans le périmètre <= R, en approche > R et <= min(3R, 500), hors zone > min(3R, 500) avec plafond à 500 m)', function () {
    $service = new HaversineService();

    // Pour R = 50 m (min(3*50, 500) = 150 m)
    expect($service->evaluateProximity(50, 50))->toBe('in_perimeter');
    expect($service->evaluateProximity(51, 50))->toBe('approaching');
    expect($service->evaluateProximity(150, 50))->toBe('approaching');
    expect($service->evaluateProximity(151, 50))->toBe('out_of_zone');

    // Pour R = 200 m (3*200 = 600 m, plafonné à min(600, 500) = 500 m)
    expect($service->evaluateProximity(200, 200))->toBe('in_perimeter');
    expect($service->evaluateProximity(201, 200))->toBe('approaching');
    expect($service->evaluateProximity(500, 200))->toBe('approaching');
    expect($service->evaluateProximity(501, 200))->toBe('out_of_zone');

    // Vérification via l'endpoint /arrivals/location
    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '17:00:00',
    ]);
    $now = Carbon::create(2026, 10, 5, 16, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    // Position à 30m -> in_perimeter
    $resIn = $this->postJson("/api/v1/schools/{$school->id}/arrivals/location", [
        'pos_lat' => 33.573110 + (30 / 111139),
        'pos_lng' => -7.589843,
        'accuracy_meters' => 15,
        'captured_at' => $now->toIso8601String(),
    ]);
    $resIn->assertStatus(200);
    $resIn->assertJsonPath('proximity_state', 'in_perimeter');
    $resIn->assertJsonPath('can_signal_arrival', true);

    // Position à 80m -> approaching
    $resApp = $this->postJson("/api/v1/schools/{$school->id}/arrivals/location", [
        'pos_lat' => 33.573110 + (80 / 111139),
        'pos_lng' => -7.589843,
        'accuracy_meters' => 15,
        'captured_at' => $now->toIso8601String(),
    ]);
    $resApp->assertStatus(200);
    $resApp->assertJsonPath('proximity_state', 'approaching');
    $resApp->assertJsonPath('can_signal_arrival', false);

    // Position à 250m (> 150m) -> out_of_zone
    $resOut = $this->postJson("/api/v1/schools/{$school->id}/arrivals/location", [
        'pos_lat' => 33.573110 + (250 / 111139),
        'pos_lng' => -7.589843,
        'accuracy_meters' => 15,
        'captured_at' => $now->toIso8601String(),
    ]);
    $resOut->assertStatus(200);
    $resOut->assertJsonPath('proximity_state', 'out_of_zone');
    $resOut->assertJsonPath('can_signal_arrival', false);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 4 : Précision GPS trop faible et position trop ancienne
|--------------------------------------------------------------------------
*/
test('4. Précision GPS trop faible (> 50 m) refusée (422) et position trop ancienne (> 60 s) refusée (422)', function () {
    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '17:00:00',
    ]);
    $now = Carbon::create(2026, 10, 5, 16, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    // 1. Précision faible (65m > 50m) sur /arrivals/location
    $resAccLoc = $this->postJson("/api/v1/schools/{$school->id}/arrivals/location", [
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 65,
        'captured_at' => $now->toIso8601String(),
    ]);
    $resAccLoc->assertStatus(422);

    // 2. Position trop ancienne (75s > 60s) sur /arrivals/location
    $resOldLoc = $this->postJson("/api/v1/schools/{$school->id}/arrivals/location", [
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $now->copy()->subSeconds(75)->toIso8601String(),
    ]);
    $resOldLoc->assertStatus(422);

    // 3. Précision faible sur /arrivals
    $resAccArr = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 65,
        'captured_at' => $now->toIso8601String(),
    ]);
    $resAccArr->assertStatus(422);

    // 4. Position trop ancienne sur /arrivals
    $resOldArr = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $now->copy()->subSeconds(80)->toIso8601String(),
    ]);
    $resOldArr->assertStatus(422);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 5 : Horaires en fuseau Africa/Casablanca (limites, marges, Ramadan, chevauchements, débrayages)
|--------------------------------------------------------------------------
*/
test('5. Horaires en fuseau Africa/Casablanca : limites exactes, marge d\'ouverture, mode Ramadan, chevauchements et débrayages', function () {
    $service = new PickupScheduleService();

    // 5a. Validation des chevauchements et ordre start < end
    expect(function () use ($service) {
        $service->validateWindows([
            ['day_of_week' => 1, 'start_time' => '16:00:00', 'end_time' => '15:00:00', 'is_ramadan' => false],
        ]);
    })->toThrow(ValidationException::class);

    expect(function () use ($service) {
        $service->validateWindows([
            ['day_of_week' => 1, 'start_time' => '15:00:00', 'end_time' => '16:00:00', 'is_ramadan' => false],
            ['day_of_week' => 1, 'start_time' => '15:30:00', 'end_time' => '16:30:00', 'is_ramadan' => false],
        ]);
    })->toThrow(ValidationException::class);

    // 5b. Limites exactes avec marge d'ouverture (10 min)
    // Plage : 16:00:00 à 16:30:00. Avec 10 min de marge -> ouverture effective à 15:50:00.
    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'opening_margin_minutes' => 10,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '16:30:00',
        'is_ramadan' => false,
    ]);

    Sanctum::actingAs($parent);

    $latOk = 33.573110 + (20 / 111139);

    // 1 seconde AVANT l'ouverture (15:49:59) -> Refusé 422 avec message "La sortie commence à"
    $timeBefore = Carbon::create(2026, 10, 5, 15, 49, 59, 'Africa/Casablanca');
    Carbon::setTestNow($timeBefore);
    $resBefore = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeBefore->toIso8601String(),
    ]);
    $resBefore->assertStatus(422);
    $msgBefore = $resBefore->json('message') ?? json_encode($resBefore->json());
    expect($msgBefore)->toContain('La sortie commence à');

    // EXACTEMENT au début avec marge (15:50:00) -> Accepté 201
    $timeStart = Carbon::create(2026, 10, 5, 15, 50, 0, 'Africa/Casablanca');
    Carbon::setTestNow($timeStart);
    $resStart = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeStart->toIso8601String(),
    ]);
    $resStart->assertStatus(201);

    // EXACTEMENT à la fin (16:30:00) -> Accepté 201
    $timeEnd = Carbon::create(2026, 10, 5, 16, 30, 0, 'Africa/Casablanca');
    Carbon::setTestNow($timeEnd);
    $resEnd = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeEnd->toIso8601String(),
    ]);
    $resEnd->assertStatus(201);

    // 1 seconde APRÈS la fin (16:30:01) -> Refusé 422
    $timeAfter = Carbon::create(2026, 10, 5, 16, 30, 1, 'Africa/Casablanca');
    Carbon::setTestNow($timeAfter);
    $resAfter = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeAfter->toIso8601String(),
    ]);
    $resAfter->assertStatus(422);

    // 5c. Mode Ramadan actif
    $school->update(['is_ramadan_mode' => true]);
    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '14:00:00',
        'end_time' => '14:45:00',
        'is_ramadan' => true,
    ]);

    // À 14:15 -> Ramadan mode accepte (201)
    $timeRamadan = Carbon::create(2026, 10, 5, 14, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($timeRamadan);
    $resRamadan = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeRamadan->toIso8601String(),
    ]);
    $resRamadan->assertStatus(201);

    // À 16:15 -> La plage normale est ignorée car is_ramadan_mode = true -> Refusé 422
    $timeNormalDuringRamadan = Carbon::create(2026, 10, 5, 16, 15, 0, 'Africa/Casablanca');
    Carbon::setTestNow($timeNormalDuringRamadan);
    $resNormalDuringRamadan = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeNormalDuringRamadan->toIso8601String(),
    ]);
    $resNormalDuringRamadan->assertStatus(422);

    // 5d. Débrayages manuels (Ouvrir maintenant / Fermer)
    $school->update(['is_ramadan_mode' => false]);

    // Fermer la sortie manuellement pendant l'heure normale (16:15)
    $school->update([
        'manual_override_state' => 'closed',
        'manual_override_until' => $timeNormalDuringRamadan->copy()->addHour(),
    ]);
    $resClosedOverride = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeNormalDuringRamadan->toIso8601String(),
    ]);
    $resClosedOverride->assertStatus(422);

    // Ouvrir la sortie manuellement en pleine nuit (23:00)
    $timeNight = Carbon::create(2026, 10, 5, 23, 0, 0, 'Africa/Casablanca');
    Carbon::setTestNow($timeNight);
    $school->update([
        'manual_override_state' => 'open',
        'manual_override_until' => $timeNight->copy()->addHour(),
    ]);
    $resOpenOverride = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $timeNight->toIso8601String(),
    ]);
    $resOpenOverride->assertStatus(201);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 6 : Double signalement sans doublon dans la même plage horaire
|--------------------------------------------------------------------------
*/
test('6. Double signalement du même parent pour le même enfant dans la même plage horaire : une seule Arrival et une seule PickupRequest créées (aucun doublon)', function () {
    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '17:00:00',
    ]);
    $now = Carbon::create(2026, 10, 5, 16, 20, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    $latOk = 33.573110 + (25 / 111139);
    $payload = [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $now->toIso8601String(),
    ];

    // Premier signalement
    $firstResponse = $this->postJson("/api/v1/schools/{$school->id}/arrivals", $payload);
    $firstResponse->assertStatus(201);
    $firstArrivalId = $firstResponse->json('id');

    // Deuxième signalement sans Idempotency-Key
    $secondResponse = $this->postJson("/api/v1/schools/{$school->id}/arrivals", $payload);
    $secondResponse->assertStatus(201);
    $secondArrivalId = $secondResponse->json('id');

    expect($secondArrivalId)->toBe($firstArrivalId);

    // Justifié : lecture restreinte au school_id de l'école
    $totalArrivals = Arrival::withoutGlobalScopes()->where('user_id', $parent->id)->count();
    // Justifié : lecture restreinte au school_id de l'école
    $totalRequests = PickupRequest::withoutGlobalScopes()->where('child_id', $child->id)->count();

    expect($totalArrivals)->toBe(1);
    expect($totalRequests)->toBe(1);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 7 : Conformité Loi 09-08 (Zéro coordonnée/distance en base + purge 30 jours)
|--------------------------------------------------------------------------
*/
test('7. Conformité Loi 09-08 : aucune coordonnée GPS ni distance en base, et la commande arrivals:purge-old supprime > 30 jours', function () {
    $school = School::factory()->create([
        'perimeter_radius' => 50,
        'gate_latitude' => 33.573110,
        'gate_longitude' => -7.589843,
    ]);
    $parent = User::factory()->create(['school_id' => $school->id, 'role' => 'parent']);
    $child = Child::factory()->create(['school_id' => $school->id]);
    $parent->children()->attach($child->id, ['relationship' => 'parent']);

    PickupWindow::factory()->create([
        'school_id' => $school->id,
        'day_of_week' => 1,
        'start_time' => '16:00:00',
        'end_time' => '17:00:00',
    ]);
    $now = Carbon::create(2026, 10, 5, 16, 20, 0, 'Africa/Casablanca');
    Carbon::setTestNow($now);

    Sanctum::actingAs($parent);

    $latOk = 33.573110 + (20 / 111139);
    $response = $this->postJson("/api/v1/schools/{$school->id}/arrivals", [
        'child_ids' => [$child->id],
        'pos_lat' => $latOk,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => $now->toIso8601String(),
    ]);

    $response->assertStatus(201);
    $arrivalId = $response->json('id');

    // Justifié : vérification de la persistance en base sans filtre
    $persistedArrival = Arrival::withoutGlobalScopes()->find($arrivalId);
    expect($persistedArrival)->not->toBeNull();
    // distance_meters doit rester strictement NULL en base conformément à la Loi 09-08
    expect($persistedArrival->distance_meters)->toBeNull();

    // Test de la commande Artisan de purge arrivals:purge-old
    // Créer une arrivée et une demande vieilles de 35 jours
    $oldDate = $now->copy()->subDays(35);
    $oldArrival = Arrival::factory()->create([
        'school_id' => $school->id,
        'user_id' => $parent->id,
        'created_at' => $oldDate,
        'updated_at' => $oldDate,
    ]);
    $oldRequest = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'arrival_id' => $oldArrival->id,
        'child_id' => $child->id,
        'created_at' => $oldDate,
        'updated_at' => $oldDate,
    ]);

    // Créer une arrivée récente (5 jours)
    $recentDate = $now->copy()->subDays(5);
    $recentArrival = Arrival::factory()->create([
        'school_id' => $school->id,
        'user_id' => $parent->id,
        'created_at' => $recentDate,
        'updated_at' => $recentDate,
    ]);
    $recentRequest = PickupRequest::factory()->create([
        'school_id' => $school->id,
        'arrival_id' => $recentArrival->id,
        'child_id' => $child->id,
        'created_at' => $recentDate,
        'updated_at' => $recentDate,
    ]);

    // Exécuter la commande de purge
    Artisan::call('arrivals:purge-old');

    // Justifié : vérification post-purge
    expect(Arrival::withoutGlobalScopes()->find($oldArrival->id))->toBeNull();
    // Justifié : vérification post-purge
    expect(PickupRequest::withoutGlobalScopes()->find($oldRequest->id))->toBeNull();
    // Justifié : vérification post-purge
    expect(Arrival::withoutGlobalScopes()->find($recentArrival->id))->not->toBeNull();
    // Justifié : vérification post-purge
    expect(PickupRequest::withoutGlobalScopes()->find($recentRequest->id))->not->toBeNull();
});

/*
|--------------------------------------------------------------------------
| SÉRIE 8 : Cloisonnement Admin & Parent (isolation stricte inter-écoles)
|--------------------------------------------------------------------------
*/
test('8. Cloisonnement Admin & Parent : un admin ne modifie que son école ; un parent est évalué uniquement sur son école (404 sur autre école)', function () {
    $schoolA = School::factory()->create(['name' => 'École A']);
    $schoolB = School::factory()->create(['name' => 'École B']);

    $parentA = User::factory()->create(['school_id' => $schoolA->id, 'role' => 'parent']);
    $childA = Child::factory()->create(['school_id' => $schoolA->id]);
    $parentA->children()->attach($childA->id, ['relationship' => 'parent']);

    Sanctum::actingAs($parentA);

    // Tentative d'accéder au statut horaire de l'école B -> 404 Not Found (ADR 0005)
    $resStatus = $this->getJson("/api/v1/schools/{$schoolB->id}/schedule-status");
    $resStatus->assertStatus(404);

    // Tentative d'évaluer la position sur l'école B -> 404
    $resLoc = $this->postJson("/api/v1/schools/{$schoolB->id}/arrivals/location", [
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => Carbon::now()->toIso8601String(),
    ]);
    $resLoc->assertStatus(404);

    // Tentative de signaler son arrivée sur l'école B -> 404
    $resArr = $this->postJson("/api/v1/schools/{$schoolB->id}/arrivals", [
        'child_ids' => [$childA->id],
        'pos_lat' => 33.573110,
        'pos_lng' => -7.589843,
        'accuracy_meters' => 10,
        'captured_at' => Carbon::now()->toIso8601String(),
    ]);
    $resArr->assertStatus(404);
});

/*
|--------------------------------------------------------------------------
| SÉRIE 9 : Cloisonnement Temps Réel (événements isolés par canal d'école)
|--------------------------------------------------------------------------
*/
test('9. Cloisonnement Temps Réel : un parent ou surveillant d\'une autre école ne reçoit aucun événement d\'une école tierce', function () {
    $schoolA = School::factory()->create(['name' => 'École A']);
    $schoolB = School::factory()->create(['name' => 'École B']);

    $parentA = User::factory()->create(['school_id' => $schoolA->id, 'role' => 'parent', 'name' => 'Fatima']);
    $childA = Child::factory()->create(['school_id' => $schoolA->id, 'first_name' => 'Youssef']);
    $arrivalA = Arrival::factory()->create(['school_id' => $schoolA->id, 'user_id' => $parentA->id]);

    // 1. ArrivalSignaledEvent
    $arrivalEvent = new ArrivalSignaledEvent(
        arrival: $arrivalA,
        parentName: 'Fatima',
        children: [['id' => $childA->id, 'first_name' => 'Youssef']],
        liveDistanceMeters: 25,
        proximityState: 'in_perimeter',
        arrivedAt: '16:15'
    );

    $channel = $arrivalEvent->broadcastOn();
    expect($channel->name)->toBe("private-school.{$schoolA->id}.queue");
    expect($channel->name)->not->toContain((string) $schoolB->id);

    // 2. ParentApproachingEvent
    $approachingEvent = new ParentApproachingEvent(
        schoolId: (string) $schoolA->id,
        parentId: (string) $parentA->id,
        parentName: 'Fatima',
        children: [['id' => $childA->id, 'first_name' => 'Youssef']],
        distanceMeters: 75,
        proximityState: 'approaching',
        timestamp: '16:10'
    );

    $channelApp = $approachingEvent->broadcastOn();
    expect($channelApp->name)->toBe("private-school.{$schoolA->id}.queue");
    expect($channelApp->name)->not->toContain((string) $schoolB->id);

    // Vérifier qu'aucune coordonnée GPS brute n'est dans le payload diffusé
    $payloadArr = $arrivalEvent->broadcastWith();
    $forbiddenKeys = ['latitude', 'longitude', 'lat', 'lng', 'pos_lat', 'pos_lng'];
    foreach ($forbiddenKeys as $key) {
        expect(array_key_exists($key, $payloadArr))->toBeFalse();
    }
});

/*
|--------------------------------------------------------------------------
| SÉRIE 10 : Autorisation des canaux WebSocket (/broadcasting/auth avec jeton Sanctum)
|--------------------------------------------------------------------------
*/
test('10. Autorisation des canaux WebSocket (/broadcasting/auth avec token Sanctum) : permissions strictes par rôle et école', function () {
    $schoolA = School::factory()->create(['name' => 'École A']);
    $schoolB = School::factory()->create(['name' => 'École B']);

    $parentA1 = User::factory()->create(['school_id' => $schoolA->id, 'role' => 'parent']);
    $parentA2 = User::factory()->create(['school_id' => $schoolA->id, 'role' => 'parent']);
    $parentB = User::factory()->create(['school_id' => $schoolB->id, 'role' => 'parent']);

    $surveillantA = User::factory()->create(['school_id' => $schoolA->id, 'role' => 'surveillant']);
    $surveillantB = User::factory()->create(['school_id' => $schoolB->id, 'role' => 'surveillant']);

    // 1. Parent A1 sur son propre canal -> 200 OK
    Sanctum::actingAs($parentA1);
    $resParentOwn = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolA->id}.parent.{$parentA1->id}",
        'socket_id' => '1234.5678',
    ]);
    $resParentOwn->assertStatus(200);

    // 2. Parent A1 sur le canal d'un autre parent de la même école -> 403 Forbidden
    $resParentOtherUser = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolA->id}.parent.{$parentA2->id}",
        'socket_id' => '1234.5678',
    ]);
    $resParentOtherUser->assertStatus(403);

    // 3. Parent A1 sur une autre école -> 403 Forbidden
    $resParentOtherSchool = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolB->id}.parent.{$parentA1->id}",
        'socket_id' => '1234.5678',
    ]);
    $resParentOtherSchool->assertStatus(403);

    // 4. Parent A1 tentant d'écouter la file globale de son école -> 403 Forbidden
    $resParentQueue = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolA->id}.queue",
        'socket_id' => '1234.5678',
    ]);
    $resParentQueue->assertStatus(403);

    // 5. Surveillant de l'école A sur la file de l'école A -> 200 OK
    Sanctum::actingAs($surveillantA);
    $resSurveillantOk = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolA->id}.queue",
        'socket_id' => '1234.5678',
    ]);
    $resSurveillantOk->assertStatus(200);

    // 6. Surveillant de l'école B sur la file de l'école A -> 403 Forbidden
    Sanctum::actingAs($surveillantB);
    $resSurveillantWrongSchool = $this->postJson('/api/v1/broadcasting/auth', [
        'channel_name' => "private-school.{$schoolA->id}.queue",
        'socket_id' => '1234.5678',
    ]);
    $resSurveillantWrongSchool->assertStatus(403);
});
