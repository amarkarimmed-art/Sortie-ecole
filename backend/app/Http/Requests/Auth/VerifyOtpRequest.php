<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validation de la vérification d'OTP (F01 — CA3, CA4).
 */
class VerifyOtpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Route publique
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'min:8', 'max:20'],
            'code' => ['required', 'string', 'size:6'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'phone.required' => 'Le numéro de téléphone est obligatoire.',
            'code.required' => 'Le code OTP est obligatoire.',
            'code.size' => 'Le code OTP doit contenir exactement 6 chiffres.',
        ];
    }
}
