<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\School;
use App\Models\User;

/**
 * Policy de la file d'attente — F02 : Tablette d'accueil.
 *
 * Règles d'accès :
 *  - R1 : Seuls les rôles `concierge` et `director` peuvent accéder à la file.
 *  - R2 : Un agent d'école A ne peut jamais voir la file de l'école B (HTTP 404 strict).
 *
 * SQUELETTE — logique non implémentée (retourne toujours false pour rester rouge).
 * L'implémentation sera effectuée à l'étape 5 (TDD vert).
 */
class QueuePolicy extends BasePolicy
{
    protected function school(): string
    {
        return 'school_id';
    }

    /**
     * Vérifier que l'utilisateur a le rôle requis pour voir la file.
     *
     * Rôles autorisés : concierge, director.
     * Tout autre rôle (parent, surveillant) reçoit HTTP 403.
     *
     * Isolation multi-école : si school_id ne correspond pas → HTTP 404 (jamais 403).
     */
    public function viewQueue(User $user, School $school): bool
    {
        if ((string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        return in_array($user->role, ['concierge', 'director'], true);
    }

    /**
     * Vérifier que l'utilisateur peut effectuer une remise (handover).
     *
     * SQUELETTE — non implémenté.
     */
    public function handover(User $user, School $school): bool
    {
        // TODO(F02-CA4): Vérifier le rôle concierge|director ET l'appartenance school_id
        return false;
    }

    /**
     * Vérifier que l'utilisateur peut confirmer la présence d'un parent hors-rayon.
     *
     * SQUELETTE — non implémenté.
     */
    public function confirmPresence(User $user, School $school): bool
    {
        // TODO(F02-CA4): Vérifier le rôle concierge|director ET l'appartenance school_id
        return false;
    }
}
