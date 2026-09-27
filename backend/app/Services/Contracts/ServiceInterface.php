<?php

declare(strict_types=1);

namespace App\Services\Contracts;

/**
 * Contrat générique pour les Services.
 *
 * Un Service encapsule une unité de logique métier
 * réutilisable, invoquée par les Actions.
 */
interface ServiceInterface
{
    /**
     * Exécuter la logique du service.
     */
    public function handle(array $data): mixed;
}
