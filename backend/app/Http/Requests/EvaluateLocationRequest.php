<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Models\School;
use Illuminate\Foundation\Http\FormRequest;

class EvaluateLocationRequest extends FormRequest
{
    public function authorize(): bool
    {
        $school = $this->route('school');
        $user = $this->user();

        if (! $user || ! $school) {
            return false;
        }

        $schoolId = $school instanceof School ? (string) $school->id : (string) $school;

        if ((string) $user->school_id !== $schoolId) {
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
            'pos_lat' => ['nullable', 'numeric'],
            'pos_lng' => ['nullable', 'numeric'],
            'lat' => ['nullable', 'numeric'],
            'lng' => ['nullable', 'numeric'],
            'accuracy_meters' => ['nullable', 'numeric'],
            'accuracy' => ['nullable', 'numeric'],
            'captured_at' => ['nullable'],
            'timestamp' => ['nullable'],
        ];
    }
}
