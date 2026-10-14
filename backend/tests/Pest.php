<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case Configuration (Pest)
|--------------------------------------------------------------------------
|
| Les tests Feature étendent Tests\TestCase et utilisent RefreshDatabase
| contre PostgreSQL (interdiction formelle de SQLite).
|
*/

uses(
    TestCase::class,
    RefreshDatabase::class,
)->in('Feature');

use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;

function actingAsSurveillant(School $school): User
{
    $user = User::factory()->surveillant()->create(['school_id' => $school->id]);
    Sanctum::actingAs($user);

    return $user;
}

function actingAsConcierge(School $school): User
{
    $user = User::factory()->concierge()->create(['school_id' => $school->id]);
    Sanctum::actingAs($user);

    return $user;
}

function callClass(School $school, PickupRequest $request, ?string $key = null): TestResponse
{
    $key ??= (string) Str::uuid();
    $schoolId = $school->public_id ?? $school->id;
    $requestId = $request->public_id ?? $request->id;

    return test()->withHeader('Idempotency-Key', $key)
        ->postJson("/api/v1/schools/{$schoolId}/pickup-requests/{$requestId}/call");
}

function markDepart(School $school, PickupRequest $request, ?string $key = null): TestResponse
{
    $key ??= (string) Str::uuid();
    $schoolId = $school->public_id ?? $school->id;
    $requestId = $request->public_id ?? $request->id;

    return test()->withHeader('Idempotency-Key', $key)
        ->postJson("/api/v1/schools/{$schoolId}/pickup-requests/{$requestId}/depart");
}

