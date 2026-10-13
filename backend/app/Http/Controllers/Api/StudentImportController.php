<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Auth\ImportStudentsAction;
use App\Http\Controllers\BaseController;
use App\Models\School;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur d'import CSV des élèves (F01 — CA5, CA6).
 *
 * Réservé aux utilisateurs ayant le rôle 'director'.
 * Mince et sans logique métier (ADR 0002).
 *
 * Route :
 *   POST /api/v1/schools/{school}/students/import
 */
class StudentImportController extends BaseController
{
    /**
     * Importer les élèves depuis un fichier CSV (CA5).
     */
    public function store(
        Request $request,
        School $school,
        ImportStudentsAction $action
    ): JsonResponse {
        // Vérifier le rôle direction (isolation école — CA6)
        $user = $request->user();

        if (! $user || $user->role !== 'director') {
            abort(403, 'Réservé à la direction.');
        }

        // Isolation multi-école (ADR 0005 — CA6)
        if ($user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $request->validate([
            'file' => ['required', 'file', 'mimes:csv,txt', 'max:5120'], // max 5 Mo
        ]);

        $result = $action->handle([
            'school' => $school,
            'file' => $request->file('file'),
        ]);

        return response()->json($result, 200);
    }
}
