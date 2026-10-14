<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class QueueItemResource extends JsonResource
{
    /** @var string|null */
    public static $wrap = null;

    /**
     * Create a new anonymous resource collection.
     *
     * @param  mixed  $resource
     * @return AnonymousResourceCollection
     */
    public static function collection($resource)
    {
        return tap(parent::collection($resource), function ($collection) {
            $collection->wrap(null);
        });
    }

    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $childName = trim(($this->child?->first_name ?? '').' '.($this->child?->last_name ?? ''));

        return [
            'id' => (string) $this->id,
            'child_id' => (string) $this->child_id,
            'child_name' => $childName,
            'class_name' => $this->child?->class_name ?? '',
            'status' => $this->status,
            'waiting_zone' => null,
            'photo_url' => $this->resolvePhotoUrl(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    private function resolvePhotoUrl(): ?string
    {
        if (! $this->child?->photo_path) {
            return null;
        }

        return rescue(
            fn () => Storage::disk('minio')->temporaryUrl($this->child->photo_path, now()->addMinutes(5)),
            null,
            false
        );
    }
}
