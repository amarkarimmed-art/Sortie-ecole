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

use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('school.{schoolId}.queue', function (User $user, string $schoolId) {
    $rolesAutorises = ['concierge', 'surveillant', 'director'];

    return in_array($user->role, $rolesAutorises, true)
        && method_exists($user, 'getSchoolId')
        && $user->getSchoolId() === $schoolId;
});

Broadcast::channel('school.{schoolId}.parent.{userId}', function (User $user, string $schoolId, string $userId) {
    return $user->role === 'parent'
        && method_exists($user, 'getSchoolId')
        && $user->getSchoolId() === $schoolId
        && (string) $user->id === $userId;
});
