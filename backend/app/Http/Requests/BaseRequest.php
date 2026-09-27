<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;

/**
 * FormRequest de base abstraite — API pure JSON.
 *
 * Toutes les FormRequests retournent des erreurs de validation
 * en JSON (422), jamais de redirection HTML.
 *
 * Usage :
 *   class StoreArrivalRequest extends BaseRequest
 *   {
 *       public function rules(): array
 *       {
 *           return [
 *               'student_ids' => ['required', 'array', 'min:1'],
 *               'in_radius'   => ['required', 'boolean'],
 *           ];
 *       }
 *   }
 */
abstract class BaseRequest extends FormRequest
{
    /**
     * Déterminer si l'utilisateur est autorisé à faire cette requête.
     *
     * Par défaut autorisé — les Policies gèrent l'autorisation fine.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Règles de validation.
     *
     * @return array<string, mixed>
     */
    abstract public function rules(): array;

    /**
     * Surcharge de la gestion des erreurs de validation.
     *
     * Retourne une réponse JSON 422 au lieu d'une redirection.
     * Comportement requis pour une API pure (pas de Blade/HTML).
     *
     * @throws HttpResponseException
     */
    protected function failedValidation(Validator $validator): void
    {
        throw new HttpResponseException(
            new JsonResponse([
                'message' => 'Les données fournies ne sont pas valides.',
                'errors' => $validator->errors()->toArray(),
            ], 422)
        );
    }
}
