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

    protected function casts(): array
    {
        return array_merge(parent::casts(), [
            'in_radius' => 'boolean',
            'distance_meters' => 'integer',
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
}
