<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Modèle Journal des remises (HandoverLog) — F02 : Tablette d'accueil.
 *
 * Registre légal append-only : aucune mise à jour ni suppression autorisée.
 * Un trigger PostgreSQL renforce cette contrainte au niveau moteur.
 *
 * Conformité Loi 09-08 :
 *  - Pas de numéro de téléphone exposé.
 *  - Uniquement des UUIDs opaques pour les récupérateurs.
 *
 * @see .agents/rules/regles_agent_securite_et_loi_09_08.md §4
 */
class HandoverLog extends BaseModel
{
    use HasFactory;

    /** @var bool Pas d'updated_at sur une table append-only */
    public const UPDATED_AT = null;

    /** Types de récupérateurs autorisés */
    public const COLLECTOR_PARENT = 'parent';

    public const COLLECTOR_AUTHORIZED_PERSON = 'authorized_person';

    public const COLLECTOR_DAILY_CODE = 'daily_code';

    public const COLLECTOR_PICKUP_CARD = 'pickup_card';

    public const ALLOWED_COLLECTOR_TYPES = [
        self::COLLECTOR_PARENT,
        self::COLLECTOR_AUTHORIZED_PERSON,
        self::COLLECTOR_DAILY_CODE,
        self::COLLECTOR_PICKUP_CARD,
    ];

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'parent_user_id' => 'string',
            'authorized_person_id' => 'string',
            'created_at' => 'datetime',
        ]);
    }

    // ── Relations ────────────────────────────────────────────────────────────

    public function pickupRequest(): BelongsTo
    {
        return $this->belongsTo(PickupRequest::class);
    }

    public function agent(): BelongsTo
    {
        return $this->belongsTo(User::class, 'agent_id');
    }

    public function parentUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'parent_user_id');
    }
}
