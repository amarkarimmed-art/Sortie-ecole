<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Modèle Demande de sortie (PickupRequest).
 *
 * Machine à états : requested → class_notified → on_the_way → handed_over
 * Transitions secondaires : requested → cancelled | expired
 * Ou pending_agent_confirmation si hors rayon / sans GPS.
 */
class PickupRequest extends BaseModel
{
    use HasFactory;

    public const STATUS_REQUESTED = 'requested';

    public const STATUS_PENDING_AGENT_CONFIRMATION = 'pending_agent_confirmation';

    public const STATUS_CLASS_NOTIFIED = 'class_notified';

    public const STATUS_ON_THE_WAY = 'on_the_way';

    public const STATUS_HANDED_OVER = 'handed_over';

    public const STATUS_CANCELLED = 'cancelled';

    public const STATUS_EXPIRED = 'expired';

    protected $fillable = [
        'school_id',
        'child_id',
        'requested_by',
        'arrival_id',
        'status',
        'in_radius',
        'distance_meters',
        'idempotency_key',
        'called_by_user_id',
        'called_at',
        'departed_by_user_id',
        'departed_at',
        'proximity_state',
    ];

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'in_radius' => 'boolean',
            'distance_meters' => 'integer',
            'proximity_state' => 'string',
            'called_at' => 'datetime',
            'departed_at' => 'datetime',
        ]);
    }

    public function child(): BelongsTo
    {
        return $this->belongsTo(Child::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by');
    }

    public function arrival(): BelongsTo
    {
        return $this->belongsTo(Arrival::class);
    }

    public function appelant(): BelongsTo
    {
        return $this->belongsTo(User::class, 'called_by_user_id');
    }

    public function partiPar(): BelongsTo
    {
        return $this->belongsTo(User::class, 'departed_by_user_id');
    }
}
