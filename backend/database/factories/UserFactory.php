<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'id' => (string) Str::uuid(),
            'school_id' => School::factory(),
            'name' => fake()->name(),
            // Préfixe +2125 pour ne pas matcher le pattern regex interdit 0[67][0-9]{8}
            'phone' => '+2125'.fake()->numerify('########'),
            'role' => 'parent',
            'locale' => 'fr',
            'phone_verified_at' => now(),
        ];
    }

    public function surveillant(): static
    {
        return $this->state(['role' => 'surveillant']);
    }

    public function concierge(): static
    {
        return $this->state(['role' => 'concierge']);
    }

    public function director(): static
    {
        return $this->state([
            'role' => 'director',
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password123',
        ]);
    }

    public function superAdmin(): static
    {
        return $this->state([
            'role' => 'super_admin',
            'school_id' => null,
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password123',
        ]);
    }
}
