<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Repositories\Contracts\RepositoryInterface;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

/**
 * Repository de base abstrait.
 *
 * Fournit les opérations CRUD génériques avec filtrage
 * automatique par school_id (via le scope global BelongsToSchool
 * appliqué sur les modèles).
 *
 * Chaîne : Controller → Action → Service → Repository → Model → DB
 *
 * Usage :
 *   class PickupRepository extends BaseRepository implements RepositoryInterface
 *   {
 *       protected function getModel(): string
 *       {
 *           return PickupRequest::class;
 *       }
 *   }
 */
abstract class BaseRepository implements RepositoryInterface
{
    /**
     * Instance du modèle Eloquent.
     */
    protected Model $model;

    public function __construct()
    {
        $this->model = app($this->getModel());
    }

    /**
     * Retourner le FQCN du modèle Eloquent associé.
     */
    abstract protected function getModel(): string;

    /**
     * {@inheritDoc}
     */
    public function findById(string $id): ?Model
    {
        // Le scope BelongsToSchool filtre automatiquement par school_id.
        // Si l'enregistrement n'appartient pas à l'école → null (→ 404).
        return $this->model->newQuery()->find($id);
    }

    /**
     * {@inheritDoc}
     */
    public function findBySchool(string $schoolId): Collection
    {
        return $this->model->newQuery()
            ->where('school_id', $schoolId)
            ->get();
    }

    /**
     * {@inheritDoc}
     */
    public function create(array $data): Model
    {
        return $this->model->newQuery()->create($data);
    }

    /**
     * {@inheritDoc}
     */
    public function update(string $id, array $data): Model
    {
        $record = $this->findById($id);

        if (! $record) {
            abort(404);
        }

        $record->update($data);

        return $record->fresh();
    }

    /**
     * {@inheritDoc}
     */
    public function delete(string $id): bool
    {
        $record = $this->findById($id);

        if (! $record) {
            abort(404);
        }

        return (bool) $record->delete();
    }
}
