<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Child;
use App\Models\School;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class ChildFactory extends Factory
{
    protected $model = Child::class;

    public function definition(): array
    {
        return [
            'id' => (string) Str::uuid(),
            'school_id' => School::factory(),
            'first_name' => fake()->firstName(),
            'last_name' => fake()->lastName(),
            'class_name' => fake()->randomElement(['CP-A', 'CE1-B', 'CE2-A', 'CM1', 'CM2']),
            'photo_path' => null,
        ];
    }
}
