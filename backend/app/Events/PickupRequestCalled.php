<?php

namespace App\Events;

use App\Models\PickupRequest;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Diffusé sur school.{id}.queue après la transition requested -> class_notified.
 * Payload volontairement minimal (loi 09-08, ADR 0008, CA13/CA17).
 * Sera complété à l'implémentation (étape 6/9).
 */
class PickupRequestCalled implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public PickupRequest $pickupRequest) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel("school.{$this->pickupRequest->school_id}.queue");
    }

    public function broadcastAs(): string
    {
        return 'pickup.called';
    }

    public function broadcastWith(): array
    {
        $child = $this->pickupRequest->child;
        $childName = trim("{$child?->first_name} {$child?->last_name}");

        return [
            'request_id' => $this->pickupRequest->id,
            'school_id' => $this->pickupRequest->school_id,
            'class_name' => $child?->class_name,
            'child_name' => $childName,
        ];
    }
}
