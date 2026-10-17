<?php

declare(strict_types=1);

namespace Tests\Feature\F04;

use App\Events\PickupRequestCalled;
use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use Carbon\Carbon;
use Illuminate\Support\Facades\Event;

beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');
});

afterEach(function () {
    Carbon::setTestNow();
});

test('CA13 : le payload de pickup.called respecte la structure autorisée (request_id, school_id, class_name, child_name)', function () {
    Event::fake();

    $school = School::factory()->create();
    actingAsConcierge($school);

    $child = Child::factory()->create([
        'school_id' => $school->id,
        'first_name' => 'Adam',
        'last_name' => 'El Amrani',
        'class_name' => 'CP-B',
    ]);

    $request = PickupRequest::factory()->requested()->create([
        'school_id' => $school->id,
        'child_id' => $child->id,
    ]);

    $response = callClass($school, $request);

    $response->assertStatus(200);

    // Une fois implémenté, vérifier la structure exacte et l'absence de données personnelles sensibles
    Event::assertDispatched(PickupRequestCalled::class, function ($event) use ($request, $school) {
        $name = is_string($event) ? $event : ($event->broadcastAs() ?? get_class($event));
        if (! str_contains((string) $name, 'called')) {
            return false;
        }

        $payload = method_exists($event, 'broadcastWith') ? $event->broadcastWith() : (array) $event;

        expect($payload)->toHaveKeys(['request_id', 'school_id', 'class_name', 'child_name'])
            ->and($payload['request_id'])->toBe($request->id)
            ->and($payload['school_id'])->toBe($school->id)
            ->and($payload['class_name'])->toBe('CP-B')
            ->and($payload['child_name'])->toBe('Adam El Amrani')
            ->and($payload)->not->toHaveKeys(['photo', 'phone', 'latitude', 'longitude']);

        return true;
    });
})->group('F04', 'CA13', 'privacy');
