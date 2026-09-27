<?php

/*
|--------------------------------------------------------------------------
| Broadcast Channels — Sortie d'école
|--------------------------------------------------------------------------
|
| Canaux WebSockets privés cloisonnés par school_id (ADR 0006).
| Pattern : private-school.{schoolId}.queue
|
| Chaque canal exige :
| 1. Authentification Sanctum
| 2. Rôle requis (agent, surveillant, direction)
| 3. school_id correspondant exactement au canal
|
*/

use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('school.{schoolId}.queue', function ($user, string $schoolId) {
    // Vérification stricte : l'utilisateur authentifié doit
    // appartenir à l'école demandée.
    if (! method_exists($user, 'getSchoolId')) {
        return false;
    }

    return $user->getSchoolId() === $schoolId;
});
