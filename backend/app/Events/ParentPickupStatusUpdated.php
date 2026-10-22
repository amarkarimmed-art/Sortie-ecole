<?php

declare(strict_types=1);

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ParentPickupStatusUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $requestId,
        public string $schoolId,
        public string $parentUserId,
        public string $childId,
        public string $childName,
        public string $status,
        public string $updatedAt
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("school.{$this->schoolId}.parent.{$this->parentUserId}")];
    }

    public function broadcastAs(): string
    {
        return 'pickup.status.updated';
    }

    public function broadcastWith(): array
    {
        return [
            'request_id' => $this->requestId,
            'school_id' => $this->schoolId,
            'child_id' => $this->childId,
            'child_name' => $this->childName,
            'status' => $this->status,
            'updated_at' => $this->updatedAt,
        ];
    }
}
