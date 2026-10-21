<?php

declare(strict_types=1);

namespace App\Models\Concerns;

use App\Models\School;
use App\Models\User;
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

                SchoolScopeState::$isResolving = true;

                try {
                    // Si le modèle interrogé est User et que !Auth::hasUser(),
                    // ne pas filtrer afin de permettre à /admin/login et /super-admin/login
                    // de trouver le compte par email.
                    if ($model instanceof User && ! Auth::hasUser()) {
                        return;
                    }

                    $user = Auth::user();

                    if (! $user) {
                        return;
                    }

                    // Bypass strictement basé sur le rôle super_admin
                    if ($user->role === 'super_admin') {
                        return;
                    }

                    // Sinon (director, admin, concierge, surveillant, parent), filtre obligatoirement
                    if (method_exists($user, 'getSchoolId')) {
                        $schoolId = $user->getSchoolId();
                        if (! empty($schoolId)) {
                            $builder->where(
                                $model->getTable() . '.school_id',
                                $schoolId
                            );
                        }
                    }
                } catch (\Throwable) {
                    // Gestion de session ou contexte console
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

                if (! $user || $user->role === 'super_admin') {
                    return;
                }

                if (empty($model->school_id) && method_exists($user, 'getSchoolId') && ! empty($user->getSchoolId())) {
                    $model->school_id = $user->getSchoolId();
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
