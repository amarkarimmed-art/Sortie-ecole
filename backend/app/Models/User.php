<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToSchool;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Modèle Utilisateur (User) — Tuteurs, surveillants, agents d'accueil, direction, administrateurs.
 * Applique l'isolation multi-école (ADR 0005).
 */
class User extends Authenticatable implements FilamentUser
{
    use BelongsToSchool;
    use HasApiTokens;
    use HasFactory;
    use HasUuids;

    protected $guarded = ['id'];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'id' => 'string',
            'school_id' => 'string',
            'phone_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function canAccessPanel(Panel $panel): bool
    {
        if ($panel->getId() === 'super-admin') {
            return $this->role === 'super_admin' && empty($this->school_id);
        }

        if ($panel->getId() === 'admin') {
            if ($this->role === 'super_admin' || empty($this->school_id)) {
                return false;
            }

            if (! in_array($this->role, ['director', 'admin'], true)) {
                return false;
            }

            $school = School::withoutGlobalScopes()->find($this->school_id);
            if (! $school || $school->is_suspended) {
                return false;
            }

            return true;
        }

        return false;
    }

    public function isSuperAdmin(): bool
    {
        return $this->role === 'super_admin';
    }

    public function isDirector(): bool
    {
        return $this->role === 'director';
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
