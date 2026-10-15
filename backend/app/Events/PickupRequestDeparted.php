<?php

namespace App\Events;

use App\Models\PickupRequest;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Diffusé sur school.{id}.queue après la transition class_notified -> on_the_way.
 * Payload volontairement minimal (loi 09-08, ADR 0008, CA23).
 * Sera complété à l'implémentation (étape 6/9).
 */
class PickupRequestDeparted implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public PickupRequest $pickupRequest) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel("school.{$this->pickupRequest->school_id}.queue");
    }

    public function broadcastAs(): string
    {
        return 'pickup.departed';
    }

    public function broadcastWith(): array
    {
        $child = $this->pickupRequest->child;

        return [
            'request_id' => $this->pickupRequest->id,
            'school_id' => $this->pickupRequest->school_id,
            'child_initial' => mb_substr((string) $child?->first_name, 0, 1, 'UTF-8').'.',
            'departed_at' => $this->pickupRequest->departed_at?->toIso8601String(),
        ];
    }
}
