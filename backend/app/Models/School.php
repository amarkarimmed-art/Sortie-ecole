<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * Modèle École (School) — Clé de partitionnement multi-établissement (ADR 0005).
 */
class School extends Model
{
    use HasFactory;
    use HasUuids;

    protected $guarded = ['id'];

    protected function casts(): array
    {
        return [
            'is_suspended' => 'boolean',
            'gate_latitude' => 'float',
            'gate_longitude' => 'float',
            'perimeter_radius' => 'integer',
            'opening_margin_minutes' => 'integer',
            'is_ramadan_mode' => 'boolean',
            'manual_override_until' => 'datetime',
        ];
    }

    public function director(): HasOne
    {
        // Justifié : Relation vers le directeur sans restriction de scope
        return $this->hasOne(User::class, 'school_id')->withoutGlobalScopes()->where('role', 'director');
    }

    public function directors(): HasMany
    {
        return $this->hasMany(User::class)->where('role', 'director');
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }

    public function parents(): HasMany
    {
        return $this->hasMany(User::class)->where('role', 'parent');
    }

    public function children(): HasMany
    {
        return $this->hasMany(Child::class);
    }

    public function arrivals(): HasMany
    {
        return $this->hasMany(Arrival::class);
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class);
    }

    public function pickupWindows(): HasMany
    {
        return $this->hasMany(PickupWindow::class);
    }
}
