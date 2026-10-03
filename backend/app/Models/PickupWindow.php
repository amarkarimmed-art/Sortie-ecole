<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Modèle Fenêtre de sortie (PickupWindow).
 */
class PickupWindow extends BaseModel
{
    use HasFactory;

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'day_of_week' => 'integer',
            'is_ramadan' => 'boolean',
        ]);
    }

    public function school(): BelongsTo
    {
        return $this->belongsTo(School::class);
    }
}
