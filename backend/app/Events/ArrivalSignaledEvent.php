<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Arrival;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ArrivalSignaledEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param Arrival $arrival
     * @param string $parentName
     * @param array<int, array<string, mixed>> $children
     * @param int|null $liveDistanceMeters
     * @param string $proximityState
     * @param string $arrivedAt
     */
    public function __construct(
        public Arrival $arrival,
        public string $parentName,
        public array $children,
        public ?int $liveDistanceMeters,
        public string $proximityState,
        public string $arrivedAt
    ) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel("school.{$this->arrival->school_id}.queue");
    }

    public function broadcastAs(): string
    {
        return 'arrival.signaled';
    }

    public function broadcastWith(): array
    {
        return [
            'arrival_id' => $this->arrival->id,
            'school_id' => $this->arrival->school_id,
            'parent_id' => $this->arrival->user_id,
            'parent_name' => $this->parentName,
            'children' => $this->children,
            'distance_meters' => $this->liveDistanceMeters,
            'proximity_state' => $this->proximityState,
            'arrived_at' => $this->arrivedAt,
        ];
    }
}
