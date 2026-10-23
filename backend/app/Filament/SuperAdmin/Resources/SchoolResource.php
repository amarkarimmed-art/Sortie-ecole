<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\SchoolResource\Pages;
use App\Models\School;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Validation\Rule;

class SchoolResource extends Resource
{
    protected static ?string $model = School::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-library';

    protected static ?string $navigationLabel = 'Écoles';

    protected static ?string $modelLabel = 'École';

    protected static ?string $pluralModelLabel = 'Écoles';

    protected static ?int $navigationSort = 1;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Informations de l\'établissement')
                    ->columns(1)
                    ->maxWidth('xl')
                    ->schema([
                        // Formulaire en création (3 champs obligatoires)
                        Forms\Components\TextInput::make('name')
                            ->label("Nom de l'école")
                            ->required()
                            ->maxLength(255)
                            ->helperText(fn (string $operation): ?string => $operation === 'create'
                                ? "Nom officiel de l'établissement (utilisé aussi comme nom du compte directeur)."
                                : null),

                        Forms\Components\TextInput::make('director_email')
                            ->label('Login du directeur')
                            ->visibleOn('create')
                            ->dehydrated(true)
                            ->required()
                            ->maxLength(255)
                            ->rule(fn () => Rule::unique('users', 'email'))
                            ->helperText('Le directeur utilisera ce login pour se connecter.'),

                        Forms\Components\TextInput::make('director_password')
                            ->label('Mot de passe du directeur')
                            ->visibleOn('create')
                            ->dehydrated(true)
                            ->required()
                            ->minLength(6)
                            ->helperText('6 caractères minimum, aucune règle de complexité.')
                            ->suffixAction(
                                Forms\Components\Actions\Action::make('generatePassword')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-o-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('director_password', 'ecole' . random_int(1000, 9999)))
                            ),

                        // Formulaire en édition (coordonnées GPS facultatives)
                        Forms\Components\TextInput::make('gate_latitude')
                            ->label('Latitude du portail (facultatif)')
                            ->visibleOn('edit')
                            ->numeric()
                            ->nullable()
                            ->helperText('Coordonnée GPS du portail.'),

                        Forms\Components\TextInput::make('gate_longitude')
                            ->label('Longitude du portail (facultatif)')
                            ->visibleOn('edit')
                            ->numeric()
                            ->nullable()
                            ->helperText('Coordonnée GPS du portail.'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label("Nom de l'école")
                    ->searchable()
                    ->sortable()
                    ->weight('bold')
                    ->icon('heroicon-m-academic-cap'),

                Tables\Columns\TextColumn::make('director.email')
                    ->label('Login du directeur')
                    ->searchable()
                    ->copyable()
                    ->placeholder('Aucun directeur associé')
                    ->icon('heroicon-m-envelope'),

                Tables\Columns\TextColumn::make('is_suspended')
                    ->label('Statut')
                    ->badge()
                    ->formatStateUsing(fn (bool $state): string => $state ? 'Suspendue' : 'Active')
                    ->color(fn (bool $state): string => $state ? 'danger' : 'success')
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Date de création')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
            ])
            ->filters([
                TernaryFilter::make('is_suspended')
                    ->label('Statut')
                    ->placeholder('Toutes')
                    ->trueLabel('Suspendues')
                    ->falseLabel('Actives'),
            ])
            ->actions([
                Tables\Actions\EditAction::make()
                    ->label('Modifier'),

                Tables\Actions\Action::make('toggle_suspend')
                    ->label(fn (School $record): string => $record->is_suspended ? 'Réactiver' : 'Suspendre')
                    ->icon(fn (School $record): string => $record->is_suspended ? 'heroicon-m-check-circle' : 'heroicon-m-no-symbol')
                    ->color(fn (School $record): string => $record->is_suspended ? 'success' : 'danger')
                    ->requiresConfirmation()
                    ->modalHeading(fn (School $record): string => $record->is_suspended ? "Réactiver {$record->name}" : "Suspendre {$record->name}")
                    ->modalDescription(fn (School $record): string => $record->is_suspended
                        ? "L'accès au panneau d'administration sera immédiatement rétabli pour le directeur de cette école."
                        : "L'accès au panneau d'administration sera bloqué pour le directeur de cette école jusqu'à sa réactivation.")
                    ->action(function (School $record) {
                        $record->update(['is_suspended' => ! $record->is_suspended]);

                        Notification::make()
                            ->title($record->is_suspended ? 'École suspendue' : 'École réactivée')
                            ->body($record->is_suspended ? "L'accès pour {$record->name} est désormais suspendu." : "L'accès pour {$record->name} a été réactivé.")
                            ->color($record->is_suspended ? 'danger' : 'success')
                            ->send();
                    }),

                Tables\Actions\Action::make('reset_director_password')
                    ->label('Réinitialiser le mot de passe du directeur')
                    ->icon('heroicon-m-key')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->modalHeading(fn (School $record) => "Réinitialiser le mot de passe — {$record->name}")
                    ->modalDescription('Définissez un nouveau mot de passe simple pour le compte directeur.')
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label('Nouveau mot de passe')
                            ->required()
                            ->minLength(6)
                            ->default(fn () => 'ecole' . random_int(1000, 9999))
                            ->helperText('Minimum 6 caractères. Mot de passe simple généré automatiquement.')
                            ->suffixAction(
                                Forms\Components\Actions\Action::make('generatePassword')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-o-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('new_password', 'ecole' . random_int(1000, 9999)))
                            ),
                    ])
                    ->action(function (School $record, array $data) {
                        $director = $record->director;

                        if (! $director) {
                            Notification::make()
                                ->danger()
                                ->title('Action impossible')
                                ->body('Cette école ne possède aucun compte directeur rattaché.')
                                ->send();

                            return;
                        }

                        $director->password = $data['new_password'];
                        $director->save();

                        session()->put('flash_director_credentials', [
                            'school_name' => $record->name,
                            'login'       => $director->email,
                            'password'    => $data['new_password'],
                        ]);

                        Notification::make()
                            ->success()
                            ->title('Mot de passe directeur mis à jour')
                            ->body("Nouveau mot de passe pour {$director->email} : {$data['new_password']}")
                            ->persistent()
                            ->send();
                    }),
            ])
            ->emptyStateHeading('Aucune école pour le moment, créez la première')
            ->emptyStateDescription('Inscrivez la première école partenaire pour commencer à gérer le réseau.')
            ->emptyStateIcon('heroicon-o-building-library')
            ->emptyStateActions([
                Tables\Actions\CreateAction::make()
                    ->label('Créer une école'),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListSchools::route('/'),
            'create' => Pages\CreateSchool::route('/create'),
            'edit'   => Pages\EditSchool::route('/{record}/edit'),
        ];
    }
}
