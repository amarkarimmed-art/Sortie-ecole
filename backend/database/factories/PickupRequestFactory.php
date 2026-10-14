<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class PickupRequestFactory extends Factory
{
    protected $model = PickupRequest::class;

    public function definition(): array
    {
        return [
            'id' => (string) Str::uuid(),
            'school_id' => School::factory(),
            'child_id' => Child::factory(),
            'requested_by' => User::factory(),
            'arrival_id' => null,
            'status' => PickupRequest::STATUS_REQUESTED,
            'in_radius' => true,
            'distance_meters' => 30,
            'idempotency_key' => (string) Str::uuid(),
        ];
    }

    public function requested(): static
    {
        return $this->state([
            'status' => PickupRequest::STATUS_REQUESTED,
        ]);
    }

    public function classNotified(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => PickupRequest::STATUS_CLASS_NOTIFIED,
            'called_at' => now()->subMinutes(2),
            'called_by_user_id' => User::factory()->concierge()->state(['school_id' => $attributes['school_id'] ?? School::factory()]),
        ]);
    }

    public function onTheWay(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => PickupRequest::STATUS_ON_THE_WAY,
            'called_at' => now()->subMinutes(5),
            'called_by_user_id' => User::factory()->concierge()->state(['school_id' => $attributes['school_id'] ?? School::factory()]),
            'departed_at' => now()->subMinutes(2),
            'departed_by_user_id' => User::factory()->surveillant()->state(['school_id' => $attributes['school_id'] ?? School::factory()]),
        ]);
    }

    public function handedOver(): static
    {
        return $this->state([
            'status' => PickupRequest::STATUS_HANDED_OVER,
        ]);
    }

    public function cancelled(): static
    {
        return $this->state([
            'status' => PickupRequest::STATUS_CANCELLED,
        ]);
    }

    public function expired(): static
    {
        return $this->state([
            'status' => PickupRequest::STATUS_EXPIRED,
        ]);
    }
}
