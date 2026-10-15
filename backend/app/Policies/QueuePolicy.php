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
     */
    public function handover(User $user, School $school): bool
    {
        if ((string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        return in_array($user->role, ['concierge', 'director'], true);
    }

    /**
     * Vérifier que l'utilisateur peut confirmer la présence d'un parent hors-rayon.
     */
    public function confirmPresence(User $user, School $school): bool
    {
        if ((string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        return in_array($user->role, ['concierge', 'director'], true);
    }

    /**
     * Vérifier que l'utilisateur peut appeler une classe (call).
     *
     * Rôles autorisés : concierge, director.
     * Tout autre rôle (parent, surveillant) reçoit HTTP 403.
     */
    public function call(User $user, School $school): bool
    {
        if ((string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        return in_array($user->role, ['concierge', 'director'], true);
    }

    /**
     * Vérifier que l'utilisateur peut marquer le départ d'un élève (depart).
     *
     * Rôles autorisés : surveillant, director.
     * Tout autre rôle (concierge, parent) reçoit HTTP 403.
     */
    public function depart(User $user, School $school): bool
    {
        if ((string) $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        return in_array($user->role, ['surveillant', 'director'], true);
    }
}
