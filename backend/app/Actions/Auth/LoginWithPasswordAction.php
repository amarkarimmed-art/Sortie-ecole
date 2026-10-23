<?php

declare(strict_types=1);

namespace App\Actions\Auth;

use App\Actions\BaseAction;
use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;

class LoginWithPasswordAction extends BaseAction
{
    /**
     * @param array<string, mixed> $data ['login' => string, 'password' => string, 'app_type' => ?string, 'ip' => string]
     * @return array<string, mixed> ['status' => int, 'response' => array]
     */
    public function handle(array $data): Model|array
    {
        $login = trim((string) ($data['login'] ?? ''));
        $password = (string) ($data['password'] ?? '');
        $appType = $data['app_type'] ?? null;
        $ip = (string) ($data['ip'] ?? '127.0.0.1');

        $throttleKey = 'login:' . mb_strtolower($login) . '|' . $ip;

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            return [
                'status' => 429,
                'response' => [
                    'message' => 'Trop de tentatives, réessayez dans une minute.',
                ],
            ];
        }

        // Justifié : Recherche sans global scope pour identifier l'utilisateur lors de la connexion
        $user = User::withoutGlobalScopes()->where('email', $login)->first();

        if (! $user || empty($user->password) || ! Hash::check($password, $user->password)) {
            RateLimiter::hit($throttleKey, 60);

            return [
                'status' => 401,
                'response' => [
                    'message' => 'Identifiants incorrects.',
                ],
            ];
        }

        // Séparation stricte des rôles côté API
        if (in_array($user->role, ['director', 'admin', 'super_admin'], true)) {
            return [
                'status' => 403,
                'response' => [
                    'message' => 'Accès non autorisé sur cette application.',
                ],
            ];
        }

        if (in_array($appType, ['parent', 'app_parent'], true) && $user->role !== 'parent') {
            return [
                'status' => 403,
                'response' => [
                    'message' => 'Accès réservé aux parents.',
                ],
            ];
        }

        if (in_array($appType, ['ecole', 'app_ecole'], true) && ! in_array($user->role, ['surveillant', 'concierge'], true)) {
            return [
                'status' => 403,
                'response' => [
                    'message' => 'Accès réservé au personnel de surveillance et d\'accueil.',
                ],
            ];
        }

        // Vérification de l'école
        $school = School::withoutGlobalScopes()->find($user->school_id);
        if (! $school || $school->is_suspended) {
            return [
                'status' => 403,
                'response' => [
                    'message' => 'École suspendue, contactez l\'administration.',
                ],
            ];
        }

        // Succès : réinitialiser le rate limiter
        RateLimiter::clear($throttleKey);

        $token = $user->createToken('mobile')->plainTextToken;

        return [
            'status' => 200,
            'response' => [
                'token' => $token,
                'user'  => self::formatUserPayload($user, $school),
            ],
        ];
    }

    /**
     * Formate la charge utile de l'utilisateur pour /login et /me.
     *
     * @return array<string, mixed>
     */
    public static function formatUserPayload(User $user, School $school): array
    {
        $children = [];
        if ($user->role === 'parent') {
            // Justifié : Chargement des enfants du parent avec filtrage explicite par school_id
            $children = $user->children()->withoutGlobalScopes()->where('children.school_id', $school->id)->get()->map(fn ($child) => [
                'id'         => (string) $child->id,
                'school_id'  => (string) $child->school_id,
                'first_name' => (string) $child->first_name,
                'last_name'  => (string) $child->last_name,
                'class_name' => (string) $child->class_name,
                'photo_url'  => $child->photo_path,
            ])->values()->all();
        }

        return [
            'id'          => (string) $user->id,
            'name'        => (string) $user->name,
            'login'       => (string) $user->email,
            'phone'       => $user->phone,
            'role'        => (string) $user->role,
            'locale'      => (string) ($user->locale ?? 'fr'),
            'school_id'   => (string) $user->school_id,
            'school_name' => (string) $school->name,
            'school_logo' => $school->logo ? Storage::disk('public')->url($school->logo) : null,
            'children'    => $children,
        ];
    }
}
