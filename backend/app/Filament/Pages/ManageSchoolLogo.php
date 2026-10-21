<?php

declare(strict_types=1);

namespace App\Filament\Pages;

use App\Models\School;
use Filament\Actions\Action;
use Filament\Forms;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Pages\Page;

class ManageSchoolLogo extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-photo';

    protected static ?string $navigationLabel = 'Logo & Mon École';

    protected static ?string $title = 'Logo & Mon École';

    protected static ?int $navigationSort = 10;

    protected static string $view = 'filament.pages.manage-school-logo';

    public ?array $data = [];

    public function mount(): void
    {
        $user = auth()->user();
        if ($user && $user->school_id) {
            $school = School::withoutGlobalScopes()->find($user->school_id);
            if ($school) {
                $this->form->fill([
                    'name'           => $school->name,
                    'gate_latitude'  => $school->gate_latitude,
                    'gate_longitude' => $school->gate_longitude,
                    'logo'           => $school->logo,
                ]);
            }
        }
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Informations de l\'établissement')
                    ->description('Personnalisez le nom, les coordonnées GPS et le logo officiel de votre école.')
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->label("Nom de l'école")
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('gate_latitude')
                            ->label('Latitude du portail (facultatif)')
                            ->numeric()
                            ->nullable()
                            ->helperText('Coordonnée GPS nord/sud'),

                        Forms\Components\TextInput::make('gate_longitude')
                            ->label('Longitude du portail (facultatif)')
                            ->numeric()
                            ->nullable()
                            ->helperText('Coordonnée GPS est/ouest'),

                        Forms\Components\FileUpload::make('logo')
                            ->label("Logo de l'école")
                            ->image()
                            ->disk('public')
                            ->directory('school-logos')
                            ->visibility('public')
                            ->helperText('Le logo sera affiché dans la barre de navigation du panneau.'),
                    ])
                    ->columns(1)
                    ->maxWidth('xl'),
            ])
            ->statePath('data');
    }

    protected function getFormActions(): array
    {
        return [
            Action::make('save')
                ->label('Enregistrer les modifications')
                ->submit('save'),
        ];
    }

    public function save(): void
    {
        $data = $this->form->getState();

        $user = auth()->user();
        if (! $user || ! $user->school_id) {
            Notification::make()
                ->danger()
                ->title('Erreur')
                ->body('Aucun établissement rattaché à votre compte.')
                ->send();

            return;
        }

        $school = School::withoutGlobalScopes()->find($user->school_id);
        if ($school) {
            $school->update($data);

            Notification::make()
                ->success()
                ->title('Informations de l\'école mises à jour')
                ->body('Le nom et le logo ont été enregistrés avec succès.')
                ->send();
        }
    }
}
