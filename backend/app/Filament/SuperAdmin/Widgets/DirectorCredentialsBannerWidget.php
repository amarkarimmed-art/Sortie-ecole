<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Widgets;

use Filament\Widgets\Widget;

class DirectorCredentialsBannerWidget extends Widget
{
    protected static string $view = 'filament.widgets.director-credentials-banner';

    protected int|string|array $columnSpan = 'full';

    protected static ?int $sort = -1;

    public ?array $credentials = null;

    public function mount(): void
    {
        $this->credentials = session()->pull('flash_director_credentials');
    }

    public static function canView(): bool
    {
        return session()->has('flash_director_credentials');
    }
}
