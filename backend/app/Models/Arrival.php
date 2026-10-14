<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Modèle Arrivée (Arrival) — Regroupe les demandes de sortie d'une fratrie lors d'un appui parent.
 *
 * Règle Sécurité §2 (Loi 09-08) :
 * - Aucune coordonnée GPS brute (lat/lng) admise.
 * - Seuls in_radius et distance_meters (arrondie aux 10m) sont stockés.
 */
class Arrival extends BaseModel
{
    use HasFactory;

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'in_radius' => 'boolean',
            'distance_meters' => 'integer',
        ]);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function pickupRequests(): HasMany
    {
        return $this->hasMany(PickupRequest::class);
    }
}
