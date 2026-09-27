<?php

declare(strict_types=1);

namespace App\Repositories\Contracts;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Collection;

/**
 * Contrat générique pour les Repositories.
 *
 * Chaque Repository concret implémente cette interface
 * et étend BaseRepository. Le filtre school_id est appliqué
 * automatiquement par le scope global BelongsToSchool.
 */
interface RepositoryInterface
{
    /**
     * Trouver un enregistrement par son UUID.
     */
    public function findById(string $id): ?Model;

    /**
     * Trouver tous les enregistrements d'une école.
     */
    public function findBySchool(string $schoolId): Collection;

    /**
     * Créer un nouvel enregistrement.
     */
    public function create(array $data): Model;

    /**
     * Mettre à jour un enregistrement existant.
     */
    public function update(string $id, array $data): Model;

    /**
     * Supprimer un enregistrement.
     */
    public function delete(string $id): bool;
}
