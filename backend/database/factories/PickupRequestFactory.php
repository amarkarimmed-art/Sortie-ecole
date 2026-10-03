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
}
