<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;

/**
 * Policy de base abstraite.
 *
 * Vérifie l'appartenance à la même école (school_id).
 * Retourne 404 si école différente (jamais 403, ADR 0005).
 *
 * Usage :
 *   class PickupRequestPolicy extends BasePolicy
 *   {
 *       protected function school(): string
 *       {
 *           return 'school_id';
 *       }
 *   }
 */
abstract class BasePolicy
{
    /**
     * Nom de la colonne school_id sur le modèle protégé.
     */
    abstract protected function school(): string;

    /**
     * Vérifier que l'utilisateur et le modèle appartiennent
     * à la même école.
     *
     * Retourne true si même école, sinon abort(404).
     * On ne retourne JAMAIS 403 pour empêcher l'énumération
     * de données inter-écoles.
     */
    public function belongsToSchool(User $user, Model $model): bool
    {
        $schoolColumn = $this->school();

        if (! method_exists($user, 'getSchoolId')) {
            abort(404);
        }

        if ($user->getSchoolId() !== $model->{$schoolColumn}) {
            abort(404);
        }

        return true;
    }
}
