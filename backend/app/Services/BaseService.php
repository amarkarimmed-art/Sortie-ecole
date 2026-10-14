<?php

declare(strict_types=1);

namespace App\Services;

use App\Services\Contracts\ServiceInterface;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

/**
 * Service de base abstrait.
 *
 * Un Service encapsule une unité de logique métier réutilisable.
 * Il est invoqué par les Actions et utilise les Repositories
 * pour l'accès aux données.
 *
 * Chaîne : Controller → Action → Service → Repository → Model → DB
 *
 * Usage :
 *   class PickupService extends BaseService implements ServiceInterface
 *   {
 *       public function handle(array $data): mixed { ... }
 *   }
 */
abstract class BaseService implements ServiceInterface
{
    /**
     * {@inheritDoc}
     */
    abstract public function handle(array $data): mixed;

    /**
     * Valider les données entrantes.
     *
     * @param  array<string, mixed>  $data  Données à valider
     * @param  array<string, mixed>  $rules  Règles de validation Laravel
     * @return array<string, mixed> Données validées
     *
     * @throws ValidationException
     */
    protected function validate(array $data, array $rules = []): array
    {
        return Validator::make($data, $rules)->validate();
    }
}
