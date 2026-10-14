<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Modèle Élève (Child).
 * Applique l'isolation multi-école (ADR 0005) via BaseModel.
 */
class Child extends BaseModel
{
    use HasFactory;

    public function parents(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'child_user')
            ->withPivot('relationship')
            ->withTimestamps();
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class);
    }
}
