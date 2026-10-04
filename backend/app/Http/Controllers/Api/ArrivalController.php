<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Actions\Arrival\GetArrivalStatusAction;
use App\Actions\Arrival\SignalArrivalAction;
use App\Http\Controllers\BaseController;
use App\Http\Requests\SignalArrivalRequest;
use App\Models\School;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Contrôleur d'API pour les arrivées (F03 : « Je suis arrivé »).
 *
 * Mince et sans logique métier (ADR 0002).
 * Délègue aux actions dédiées.
 */
class ArrivalController extends BaseController
{
    /**
     * Signaler une arrivée parent (F03).
     */
    public function store(
        SignalArrivalRequest $request,
        School $school,
        SignalArrivalAction $action
    ): JsonResponse {
        $validated = $request->validated();
        $validated['user'] = $request->user();
        $validated['school'] = $school;
        $validated['idempotency_key'] = $request->header('Idempotency-Key');

        $arrival = $action->handle($validated);

        return response()->json($arrival, 201);
    }

    /**
     * Consulter le statut de l'arrivée courante (CA10).
     */
    public function status(
        Request $request,
        School $school,
        GetArrivalStatusAction $action
    ): JsonResponse {
        $user = $request->user();

        if ($user && $user->school_id !== (string) $school->id) {
            abort(404, 'École introuvable.');
        }

        $result = $action->handle([
            'user' => $user,
            'school' => $school,
        ]);

        return response()->json($result, 200);
    }
}
