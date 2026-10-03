<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\PickupWindow;
use App\Models\School;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class PickupWindowFactory extends Factory
{
    protected $model = PickupWindow::class;

    public function definition(): array
    {
        return [
            'id' => (string) Str::uuid(),
            'school_id' => School::factory(),
            'day_of_week' => 1,
            'start_time' => '15:20:00',
            'end_time' => '16:00:00',
            'is_ramadan' => false,
        ];
    }
}
