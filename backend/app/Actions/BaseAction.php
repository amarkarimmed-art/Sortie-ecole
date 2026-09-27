<?php

declare(strict_types=1);

namespace App\Actions;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;

/**
 * Action de base abstraite.
 *
 * Une Action = une intention métier unique avec une seule
 * méthode publique handle() (ADR 0002).
 *
 * Les Actions reçoivent leurs Services et Repositories
 * par injection de dépendances au constructeur (pas de new).
 *
 * Chaîne : Controller → Action → Service → Repository → Model → DB
 *
 * Usage :
 *   class SignalArrivalAction extends BaseAction
 *   {
 *       public function __construct(
 *           private readonly ArrivalService $service,
 *           private readonly ArrivalRepository $repository,
 *       ) {}
 *
 *       public function handle(array $data): Model|array { ... }
 *   }
 */
abstract class BaseAction
{
    /**
     * Exécuter l'action métier.
     *
     * @param  array<string, mixed>  $data
     * @return Model|array<string, mixed>
     */
    abstract public function handle(array $data): Model|array;

    /**
     * Vérifier si l'utilisateur est autorisé à exécuter cette action.
     *
     * Par défaut, l'action est autorisée. Les actions concrètes
     * surchargent cette méthode pour des vérifications spécifiques.
     */
    public function authorize(User $user): bool
    {
        return true;
    }
}
