<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Models\PickupWindow;
use App\Models\School;
use App\Services\Schedule\PickupScheduleService;
use Carbon\Carbon;
use Filament\Actions\Action;
use Filament\Forms;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ManageSchoolLogo extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';

    protected static ?string $navigationLabel = "Paramètres de l'école";

    protected static ?string $title = "Paramètres de l'école";

    protected static ?string $slug = 'manage-school-logo';

    protected static ?int $navigationSort = 10;

    protected static string $view = 'filament.pages.manage-school-logo';

    public ?array $data = [];

    public array $windows = [];

    public int $activeDay = 1;

    public bool $is_ramadan_mode = false;

    public ?string $overrideState = null;

    public ?string $overrideUntil = null;

    public function mount(): void
    {
        $user = auth()->user();
        if (! $user || ! $user->school_id) {
            abort(403, 'Aucun établissement rattaché.');
        }

        // Justifié : accès restreint au school_id authentifié
        $school = School::withoutGlobalScopes()->find($user->school_id);
        if (! $school) {
            abort(404, 'École introuvable.');
        }

        $this->is_ramadan_mode = (bool) ($school->is_ramadan_mode ?? false);
        $this->overrideState = $school->manual_override_state;
        $this->overrideUntil = $school->manual_override_until
            ? Carbon::parse($school->manual_override_until)->setTimezone('Africa/Casablanca')->format('H:i')
            : null;

        $this->form->fill([
            'name'                   => $school->name,
            'logo'                   => $school->logo,
            'gate_latitude'          => $school->gate_latitude,
            'gate_longitude'         => $school->gate_longitude,
            'perimeter_radius'       => $school->perimeter_radius ?? 50,
            'opening_margin_minutes' => $school->opening_margin_minutes ?? 10,
            'is_ramadan_mode'        => $this->is_ramadan_mode,
        ]);

        $this->activeDay = (int) Carbon::now('Africa/Casablanca')->dayOfWeekIso;

        $this->loadWindows();
    }

    public function getCurrentServerTime(): string
    {
        return Carbon::now('Africa/Casablanca')->locale('fr')->isoFormat('dddd HH:mm');
    }

    public function getLiveScheduleStatus(): array
    {
        $school = $this->getSchool();
        if (! $school) {
            return ['is_open' => false, 'message_fr' => 'École introuvable'];
        }
        return (new PickupScheduleService())->getCurrentStatus($school, Carbon::now('Africa/Casablanca'));
    }

    public function loadWindows(): void
    {
        $user = auth()->user();
        if (! $user || ! $user->school_id) {
            return;
        }

        // Justifié : school_id explicite de l'utilisateur authentifié
        $rawWindows = PickupWindow::withoutGlobalScopes()
            ->where('school_id', $user->school_id)
            ->orderBy('day_of_week')
            ->orderBy('start_time')
            ->get();

        $this->windows = $rawWindows->map(function ($w) {
            return [
                'id'          => $w->id,
                'day_of_week' => (int) $w->day_of_week,
                'start_time'  => substr((string) $w->start_time, 0, 5),
                'end_time'    => substr((string) $w->end_time, 0, 5),
                'is_ramadan'  => (bool) $w->is_ramadan,
            ];
        })->toArray();
    }

    public function updatedIsRamadanMode(bool $value): void
    {
        $this->data['is_ramadan_mode'] = $value;
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Logo & Identité')
                    ->description("Personnalisez le nom et le logo officiel de votre établissement.")
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->label("Nom de l'école")
                            ->required()
                            ->maxLength(255),

                        Forms\Components\FileUpload::make('logo')
                            ->label("Logo officiel")
                            ->image()
                            ->disk('public')
                            ->directory('school-logos')
                            ->visibility('public')
                            ->helperText('Affiché dans la barre de navigation et sur les applications mobiles.'),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Périmètre GPS')
                    ->description('Positionnez le portail de sortie et définissez le rayon autorisé pour les arrivées.')
                    ->schema([
                        Forms\Components\Hidden::make('gate_latitude')
                            ->live(),

                        Forms\Components\Hidden::make('gate_longitude')
                            ->live(),

                        Forms\Components\TextInput::make('perimeter_radius')
                            ->label('Rayon du périmètre (en mètres)')
                            ->numeric()
                            ->required()
                            ->minValue(10)
                            ->maxValue(500)
                            ->default(50)
                            ->suffix('mètres')
                            ->helperText('Rayon dans lequel le parent est considéré au portail (10 m à 500 m).')
                            ->live(),
                    ]),

                Forms\Components\Section::make('Paramètres des Horaires')
                    ->description('Configurez les marges d\'ouverture et le régime horaire actif.')
                    ->schema([
                        Forms\Components\Toggle::make('is_ramadan_mode')
                            ->label('Activer le mode Ramadan')
                            ->helperText('Active les horaires spéciaux du Ramadan pour l\'école.')
                            ->live()
                            ->afterStateUpdated(function ($state) {
                                $this->is_ramadan_mode = (bool) $state;
                            }),

                        Forms\Components\TextInput::make('opening_margin_minutes')
                            ->label('Marge d\'ouverture avant le début')
                            ->numeric()
                            ->required()
                            ->minValue(0)
                            ->maxValue(60)
                            ->default(10)
                            ->suffix('minutes')
                            ->helperText('Permet aux parents de signaler leur arrivée X minutes avant l\'horaire de sonnerie.'),
                    ])
                    ->columns(2),
            ])
            ->statePath('data');
    }

    public function openNow(): void
    {
        $school = $this->getSchool();
        if (! $school) return;

        $until = Carbon::now('Africa/Casablanca')->addMinutes(60);
        $school->update([
            'manual_override_state' => 'open',
            'manual_override_until' => $until,
        ]);

        $this->overrideState = 'open';
        $this->overrideUntil = $until->format('H:i');

        Notification::make()
            ->success()
            ->title('Sortie ouverte immédiatement')
            ->body("La sortie est ouverte pour 60 minutes (jusqu'à {$this->overrideUntil}).")
            ->send();
    }

    public function closeNow(): void
    {
        $school = $this->getSchool();
        if (! $school) return;

        $until = Carbon::now('Africa/Casablanca')->addMinutes(60);
        $school->update([
            'manual_override_state' => 'closed',
            'manual_override_until' => $until,
        ]);

        $this->overrideState = 'closed';
        $this->overrideUntil = $until->format('H:i');

        Notification::make()
            ->warning()
            ->title('Sortie fermée manuellement')
            ->body("Le signalement d'arrivée est bloqué pour 60 minutes.")
            ->send();
    }

    public function resetOverride(): void
    {
        $school = $this->getSchool();
        if (! $school) return;

        $school->update([
            'manual_override_state' => null,
            'manual_override_until' => null,
        ]);

        $this->overrideState = null;
        $this->overrideUntil = null;

        Notification::make()
            ->info()
            ->title('Horaires automatiques rétablis')
            ->body("La sortie suit désormais les plages configurées.")
            ->send();
    }

    public function setActiveDay(int $day): void
    {
        $this->activeDay = $day;
    }

    public function addWindow(int $day): void
    {
        $this->windows[] = [
            'id'          => null,
            'day_of_week' => $day,
            'start_time'  => '16:00',
            'end_time'    => '17:00',
            'is_ramadan'  => $this->is_ramadan_mode,
        ];
    }

    public function removeWindow(int $index): void
    {
        if (isset($this->windows[$index])) {
            unset($this->windows[$index]);
            $this->windows = array_values($this->windows);
        }
    }

    public function copyDayToAll(int $sourceDay): void
    {
        $school = $this->getSchool();
        if (! $school) {
            Notification::make()->danger()->title('Erreur')->body('Aucun établissement lié.')->send();
            return;
        }

        $sourceWindows = array_values(array_filter($this->windows, function ($w) use ($sourceDay) {
            return (int) $w['day_of_week'] === $sourceDay && (bool) $w['is_ramadan'] === $this->is_ramadan_mode;
        }));

        if (empty($sourceWindows)) {
            Notification::make()
                ->warning()
                ->title('Aucune plage à copier')
                ->body('Définissez au moins une plage sur ce jour avant de la copier.')
                ->send();
            return;
        }

        // Valider le format des plages sources
        foreach ($sourceWindows as $sw) {
            $s = substr((string) ($sw['start_time'] ?? ''), 0, 5);
            $e = substr((string) ($sw['end_time'] ?? ''), 0, 5);
            if (empty($s) || empty($e)) {
                Notification::make()->danger()->title('Horaires incomplets')->body('Veuillez renseigner les heures de début et de fin.')->send();
                return;
            }
            if ($s === $e) {
                Notification::make()->danger()->title('Horaires invalides')->body("L'heure de début ({$s}) doit être différente de l'heure de fin ({$e}).")->send();
                return;
            }
        }

        // Préparer les nouvelles plages pour tous les 7 jours (1 à 7)
        $otherRegimeWindows = array_filter($this->windows, function ($w) {
            return (bool) ($w['is_ramadan'] ?? false) !== $this->is_ramadan_mode;
        });

        $newRegimeWindows = [];
        for ($day = 1; $day <= 7; $day++) {
            foreach ($sourceWindows as $sw) {
                $newRegimeWindows[] = [
                    'id'          => null,
                    'day_of_week' => $day,
                    'start_time'  => substr((string) $sw['start_time'], 0, 5),
                    'end_time'    => substr((string) $sw['end_time'], 0, 5),
                    'is_ramadan'  => (bool) $this->is_ramadan_mode,
                ];
            }
        }

        $this->windows = array_values(array_merge($otherRegimeWindows, $newRegimeWindows));

        // Enregistrer immédiatement en base de données sur tous les 7 jours
        $this->save();

        Notification::make()
            ->success()
            ->title('Plages copiées et enregistrées')
            ->body('Plages copiées et enregistrées sur tous les jours de la semaine (du Lundi au Dimanche).')
            ->send();
    }

    public function save(): void
    {
        $school = $this->getSchool();
        if (! $school) {
            Notification::make()->danger()->title('Erreur')->body('Aucun établissement lié.')->send();
            return;
        }

        $formData = $this->form->getState();
        $isRamadanMode = (bool) ($formData['is_ramadan_mode'] ?? $this->is_ramadan_mode);

        // 1. Validation des plages horaires via le service
        try {
            (new PickupScheduleService())->validateWindows($this->windows);
        } catch (ValidationException $e) {
            $msg = collect($e->errors())->flatten()->first() ?: 'Erreur de validation des plages horaires.';
            Notification::make()->danger()->title('Validation des horaires')->body($msg)->send();
            return;
        }

        // 2. Mise à jour de l'école et des plages horaires
        DB::transaction(function () use ($school, $formData, $isRamadanMode) {
            $school->update([
                'name'                   => $formData['name'],
                'logo'                   => $formData['logo'] ?? $school->logo,
                'gate_latitude'          => $formData['gate_latitude'] ? (float) $formData['gate_latitude'] : null,
                'gate_longitude'         => $formData['gate_longitude'] ? (float) $formData['gate_longitude'] : null,
                'perimeter_radius'       => (int) ($formData['perimeter_radius'] ?? 50),
                'opening_margin_minutes' => (int) ($formData['opening_margin_minutes'] ?? 10),
                'is_ramadan_mode'        => $isRamadanMode,
                'manual_override_state'  => null,
                'manual_override_until'  => null,
            ]);

            // Justifié : synchronisation des plages restreinte au school_id de l'école
            PickupWindow::withoutGlobalScopes()
                ->where('school_id', $school->id)
                ->where('is_ramadan', $isRamadanMode)
                ->delete();

            foreach ($this->windows as $w) {
                if ((bool) ($w['is_ramadan'] ?? false) !== $isRamadanMode) {
                    continue;
                }
                if (empty($w['start_time']) || empty($w['end_time'])) {
                    continue;
                }

                $startTime = substr((string) $w['start_time'], 0, 5) . ':00';
                $endTime   = substr((string) $w['end_time'], 0, 5) . ':00';

                PickupWindow::create([
                    'school_id'   => $school->id,
                    'day_of_week' => (int) $w['day_of_week'],
                    'start_time'  => $startTime,
                    'end_time'    => $endTime,
                    'is_ramadan'  => $isRamadanMode,
                ]);
            }
        });

        $this->overrideState = null;
        $this->overrideUntil = null;
        $this->loadWindows();

        Notification::make()
            ->success()
            ->title('Paramètres enregistrés')
            ->body('Les paramètres de l\'école, le périmètre GPS et les horaires ont été mis à jour.')
            ->send();
    }

    private function getSchool(): ?School
    {
        $user = auth()->user();
        if (! $user || ! $user->school_id) return null;

        // Justifié : accès restreint au school_id authentifié
        return School::withoutGlobalScopes()->find($user->school_id);
    }
}
