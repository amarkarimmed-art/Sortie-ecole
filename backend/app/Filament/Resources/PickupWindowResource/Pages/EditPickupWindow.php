<?php

namespace App\Filament\Resources\PickupWindowResource\Pages;

use App\Filament\Resources\PickupWindowResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditPickupWindow extends EditRecord
{
    protected static string $resource = PickupWindowResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
