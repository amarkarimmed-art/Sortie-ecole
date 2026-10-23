<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ParentApproachingEvent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param string $schoolId
     * @param string $parentId
     * @param string $parentName
     * @param array<int, array<string, mixed>> $children
     * @param int $distanceMeters (en RAM uniquement, jamais en base !)
     * @param string $proximityState ('approaching' ou 'in_perimeter')
     * @param string $timestamp
     */
    public function __construct(
        public string $schoolId,
        public string $parentId,
        public string $parentName,
        public array $children,
        public int $distanceMeters,
        public string $proximityState,
        public string $timestamp
    ) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel("school.{$this->schoolId}.queue");
    }

    public function broadcastAs(): string
    {
        return 'parent.approaching';
    }

    public function broadcastWith(): array
    {
        $primaryRequestId = $this->children[0]['request_id'] ?? null;

        return [
            'school_id' => $this->schoolId,
            'parent_id' => $this->parentId,
            'parent_name' => $this->parentName,
            'children' => $this->children,
            'request_id' => $primaryRequestId,
            'distance_meters' => $this->distanceMeters,
            'proximity_state' => $this->proximityState,
            'timestamp' => $this->timestamp,
        ];
    }
}
