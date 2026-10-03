<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Arrival;
use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class ArrivalFactory extends Factory
{
    protected $model = Arrival::class;

    public function definition(): array
    {
        return [
            'id' => (string) Str::uuid(),
            'school_id' => School::factory(),
            'user_id' => User::factory(),
            'in_radius' => true,
            'distance_meters' => 30,
            'idempotency_key' => (string) Str::uuid(),
        ];
    }
}
