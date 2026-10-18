<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Models\School;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Scope;
use Illuminate\Support\Facades\Auth;

/**
 * Scope global — Isolation multi-établissement (ADR 0005).
 *
 * Ce trait applique automatiquement un filtre `school_id`
 * sur toutes les requêtes Eloquent. Toute tentative d'accès
 * à une ressource d'une autre école retourne 404 (jamais 403)
 * pour empêcher l'énumération de données.
 *
 * Usage :
 *   class PickupRequest extends BaseModel
 *   {
 *       // Le trait est déjà appliqué via BaseModel.
 *   }
 * //
 * // Note : Ne JAMAIS appeler withoutGlobalScopes() sans
 * justification explicite en commentaire d'architecture
 * (règle .agents/rules/regles_agent_style_laravel_backend.md).
 */
/**
 * État d'anti-récursion pour le scope global multi-établissement.
 */
class SchoolScopeState
{
    public static bool $isResolving = false;
}

trait BelongsToSchool
{
    /**
     * Boot du trait — enregistrement du scope global.
     */
    public static function bootBelongsToSchool(): void
    {
        static::addGlobalScope('school', new class implements Scope
        {
            public function apply(Builder $builder, Model $model): void
            {
                if (SchoolScopeState::$isResolving) {
                    return;
                }

                try {
                    if (request()?->is('admin/login*')) {
                        return;
                    }
                } catch (\Throwable) {
                    // Hors contexte HTTP
                }

                SchoolScopeState::$isResolving = true;

                try {
                    $user = Auth::user();

                    if ($user && method_exists($user, 'getSchoolId')) {
                        $schoolId = $user->getSchoolId();
                        if (!empty($schoolId)) {
                            $builder->where(
                                $model->getTable().'.school_id',
                                $schoolId
                            );
                        }
                    }
                } catch (\Throwable) {
                    // Session guard non prêt ou contexte console
                } finally {
                    SchoolScopeState::$isResolving = false;
                }
            }
        });

        // Auto-assigner school_id à la création
        static::creating(function (Model $model): void {
            if (SchoolScopeState::$isResolving) {
                return;
            }

            SchoolScopeState::$isResolving = true;

            try {
                $user = Auth::user();

                if ($user && method_exists($user, 'getSchoolId') && empty($model->school_id)) {
                    $schoolId = $user->getSchoolId();
                    if (!empty($schoolId)) {
                        $model->school_id = $schoolId;
                    }
                }
            } catch (\Throwable) {
                // Contexte non authentifié
            } finally {
                SchoolScopeState::$isResolving = false;
            }
        });
    }

    /**
     * Relation vers l'école parente.
     */
    public function school(): BelongsTo
    {
        return $this->belongsTo(School::class, 'school_id');
    }
}
