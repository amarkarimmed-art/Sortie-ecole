<?php

declare(strict_types=1);

namespace App\Actions\Auth;

use App\Actions\BaseAction;
use App\Models\Child;
use App\Models\School;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Action métier : Import CSV des élèves et création des comptes parents (F01 — CA5, CA6).
 *
 * Format CSV attendu (R3 / Q2) :
 *   prenom,nom,classe,telephone1,telephone2
 *   Aicha,Benali,CE1,+212612345678,+212698765432
 *   Youssef,Alami,CP,+212611111111,
 *
 * Règles :
 * - telephone2 est optionnel (valeur vide ou absente acceptée)
 * - Upsert idempotent : re-importer le même CSV n'a pas d'effet indésirable
 * - school_id obligatoire sur chaque enregistrement (ADR 0005)
 * - Les photos ne sont PAS importées via CSV (upload séparé — Loi 09-08 / R5)
 * - Le CSV réel ne touche jamais le dépôt Git (R3)
 */
class ImportStudentsAction extends BaseAction
{
    /**
     * @param  array<string, mixed>  $data  ['school' => School, 'file' => UploadedFile]
     * @return array<string, mixed> ['created' => int, 'updated' => int, 'errors' => array]
     */
    public function handle(array $data): Model|array
    {
        /** @var School $school */
        $school = $data['school'];
        /** @var UploadedFile $file */
        $file = $data['file'];

        $schoolId = (string) $school->id;

        $created = 0;
        $updated = 0;
        $errors = [];

        // Lire le CSV ligne par ligne (gestion mémoire pour grands fichiers)
        $handle = fopen($file->getRealPath(), 'r');

        if ($handle === false) {
            abort(422, 'Impossible de lire le fichier CSV.');
        }

        $lineNumber = 0;

        try {
            // Lire et ignorer la ligne d'en-tête
            $header = fgetcsv($handle);

            if ($header === false || count($header) < 4) {
                abort(422, 'Format CSV invalide. Colonnes attendues : prenom,nom,classe,telephone1[,telephone2]');
            }

            while (($row = fgetcsv($handle)) !== false) {
                $lineNumber++;

                // Nettoyer les valeurs
                $row = array_map('trim', $row);

                // Valider le minimum de colonnes
                if (count($row) < 4) {
                    $errors[] = "Ligne {$lineNumber} : données insuffisantes (4 colonnes minimum).";

                    continue;
                }

                [$firstName, $lastName, $className, $phone1] = $row;
                $phone2 = $row[4] ?? null;

                // Valider les champs obligatoires
                if (empty($firstName) || empty($lastName) || empty($className) || empty($phone1)) {
                    $errors[] = "Ligne {$lineNumber} : champs obligatoires manquants.";

                    continue;
                }

                DB::transaction(function () use (
                    $schoolId, $firstName, $lastName, $className,
                    $phone1, $phone2, &$created, &$updated
                ) {
                    // Créer ou mettre à jour l'élève (upsert sur school_id + first_name + last_name + class_name)
                    $childResult = Child::withoutGlobalScopes()->updateOrCreate(
                        [
                            'school_id' => $schoolId,
                            'first_name' => $firstName,
                            'last_name' => $lastName,
                            'class_name' => $className,
                        ],
                        [] // Pas d'attributs à forcer lors de la mise à jour
                    );

                    $wasCreated = $childResult->wasRecentlyCreated;

                    // Créer ou mettre à jour le parent 1 et lier à l'élève
                    if (! empty($phone1)) {
                        $this->upsertParentAndLink($schoolId, $phone1, $childResult);
                    }

                    // Parent 2 optionnel (Q2)
                    if (! empty($phone2)) {
                        $this->upsertParentAndLink($schoolId, $phone2, $childResult);
                    }

                    if ($wasCreated) {
                        $created++;
                    } else {
                        $updated++;
                    }
                });
            }
        } finally {
            fclose($handle);
        }

        return [
            'created' => $created,
            'updated' => $updated,
            'errors' => $errors,
            'total_processed' => $lineNumber,
        ];
    }

    /**
     * Crée ou met à jour un parent et l'associe à l'élève.
     */
    private function upsertParentAndLink(string $schoolId, string $phone, Child $child): void
    {
        $parent = User::withoutGlobalScopes()->updateOrCreate(
            ['phone' => $phone],
            [
                'school_id' => $schoolId,
                'name' => 'Parent', // Le nom sera complété lors de la première connexion
                'role' => 'parent',
                'locale' => 'fr',
            ]
        );

        // Attacher l'élève si pas déjà lié
        if (! $child->parents()->where('users.id', $parent->id)->exists()) {
            $child->parents()->attach($parent->id, ['relationship' => 'parent']);
        }
    }
}
