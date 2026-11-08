<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Models\School;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Validation de la requête de signalement d'arrivée (F03).
 *
 * Règles :
 * - child_ids : tableau d'UUIDs non vide
 * - pos_lat / pos_lng : coordonnées GPS obligatoires (calcul Haversine côté serveur)
 * - accuracy_meters : précision GPS (optionnelle)
 * - captured_at : horodatage de la mesure (optionnel)
 *
 * Loi 09-08 : les coordonnées ne sont jamais persistées en base.
 */
class SignalArrivalRequest extends FormRequest
{
    public function authorize(): bool
    {
        $school = $this->route('school');
        $user = $this->user();

        if (! $user || ! $school) {
            return false;
        }

        $schoolId = $school instanceof School ? $school->id : (string) $school;

        // Isolation multi-tenant stricte : si l'école ne correspond pas, renvoyer 404 (ADR 0005)
        if ($user->school_id !== $schoolId) {
            abort(404, 'École introuvable.');
        }

        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'child_ids' => ['required', 'array', 'min:1'],
            'child_ids.*' => ['required', 'uuid'],
            'pos_lat' => ['required_without:lat', 'nullable', 'numeric'],
            'pos_lng' => ['required_without:lng', 'nullable', 'numeric'],
            'lat' => ['required_without:pos_lat', 'nullable', 'numeric'],
            'lng' => ['required_without:pos_lng', 'nullable', 'numeric'],
            'accuracy_meters' => ['nullable', 'numeric'],
            'accuracy' => ['nullable', 'numeric'],
            'captured_at' => ['nullable'],
            'timestamp' => ['nullable'],
        ];
    }
}
