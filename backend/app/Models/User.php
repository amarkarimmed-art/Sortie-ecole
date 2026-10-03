<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToSchool;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Modèle Utilisateur (User) — Tuteurs, surveillants, agents d'accueil, direction.
 * Applique l'isolation multi-école (ADR 0005).
 */
class User extends Authenticatable
{
    use BelongsToSchool;
    use HasApiTokens;
    use HasFactory;
    use HasUuids;

    protected $guarded = ['id'];

    protected $hidden = [
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'id' => 'string',
            'school_id' => 'string',
            'phone_verified_at' => 'datetime',
        ];
    }

    public function getSchoolId(): string
    {
        return (string) $this->school_id;
    }

    public function school(): BelongsTo
    {
        return $this->belongsTo(School::class);
    }

    public function children(): BelongsToMany
    {
        return $this->belongsToMany(Child::class, 'child_user')
                    ->withPivot('relationship')
                    ->withTimestamps();
    }

    public function arrivals(): HasMany
    {
        return $this->hasMany(Arrival::class);
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class, 'requested_by');
    }
}
