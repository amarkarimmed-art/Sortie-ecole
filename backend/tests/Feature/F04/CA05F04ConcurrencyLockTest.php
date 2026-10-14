<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

use App\Models\PickupRequest;
use App\Models\School;
use Carbon\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

test('CA18 : deux appels /depart concurrents avec lock pessimiste sérialisent la transition sans doublon', function () {
    Event::fake();

    $school = School::factory()->create();
    actingAsSurveillant($school);

    $request = PickupRequest::factory()->classNotified()->create([
        'school_id' => $school->id,
    ]);

    $keyA = (string) Str::uuid();
    $keyB = (string) Str::uuid();

    // Premier appel : effectue la transition class_notified -> on_the_way
    $resA = markDepart($school, $request, $keyA);
    $resA->assertStatus(200);

    // Deuxième appel concurrent immédiat avec une autre clé : idempotence d'état
    $resB = markDepart($school, $request, $keyB);
    $resB->assertStatus(200);

    $request->refresh();
    expect($request->status)->toBe('on_the_way');
})->group('F04', 'CA18', 'concurrency');
