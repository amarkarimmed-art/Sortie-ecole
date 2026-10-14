<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToSchool;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * Modèle de base abstrait — Sortie d'école.
 *
 * Conventions :
 * - UUID comme clé primaire (HasUuids)
 * - Scope global BelongsToSchool pour l'isolation multi-école
 * - $guarded = ['id'] : protection de la clé primaire uniquement
 * - Pas de logique métier dans les modèles (ADR 0002)
 *
 * Chaque modèle métier étend cette classe :
 *   class PickupRequest extends BaseModel { ... }
 */
abstract class BaseModel extends Model
{
    use BelongsToSchool;
    use HasUuids;

    /**
     * Attributs protégés contre l'assignation de masse.
     *
     * @var array<int, string>
     */
    protected $guarded = ['id'];

    /**
     * Casts par défaut.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'id' => 'string',
            'school_id' => 'string',
        ];
    }

    /**
     * Scope pour filtrer par école.
     */
    public function scopeForSchool(Builder $query, string $schoolId): Builder
    {
        return $query->where($this->getTable().'.school_id', $schoolId);
    }
}
