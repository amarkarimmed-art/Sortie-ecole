<?php

declare(strict_types=1);

namespace App\Filament\SuperAdmin\Resources;

use App\Filament\SuperAdmin\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-user-circle';

    protected static ?string $navigationLabel = 'Directeurs';

    protected static ?string $modelLabel = 'Directeur';

    protected static ?string $pluralModelLabel = 'Directeurs';

    protected static ?int $navigationSort = 2;

    public static function getEloquentQuery(): Builder
    {
        // Justifié : Query sans global scope pour lister tous les directeurs de toutes les écoles
        return parent::getEloquentQuery()->withoutGlobalScopes()
            ->where('role', 'director');
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Informations du Directeur')
                    ->columns(1)
                    ->maxWidth('xl')
                    ->schema([
                        Forms\Components\Select::make('school_id')
                            ->label('École')
                            ->relationship('school', 'name')
                            ->searchable()
                            ->preload()
                            ->required()
                            ->helperText('École rattachée à ce directeur.'),

                        Forms\Components\TextInput::make('email')
                            ->label('Login')
                            ->required()
                            ->maxLength(255)
                            ->unique(User::class, 'email', ignoreRecord: true)
                            ->helperText('Le directeur utilisera ce login pour se connecter.'),

                        Forms\Components\TextInput::make('password')
                            ->label('Mot de passe')
                            ->minLength(6)
                            ->required(fn (string $operation): bool => $operation === 'create')
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->helperText('6 caractères minimum, sans règle de complexité.')
                            ->suffixAction(
                                Forms\Components\Actions\Action::make('generatePassword')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-o-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('password', 'directeur' . random_int(100, 999)))
                            ),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('school.name')
                    ->label('École')
                    ->searchable()
                    ->sortable()
                    ->weight('bold')
                    ->placeholder('Aucune école')
                    ->icon('heroicon-m-academic-cap'),

                Tables\Columns\TextColumn::make('email')
                    ->label('Login du directeur')
                    ->searchable()
                    ->sortable()
                    ->copyable()
                    ->icon('heroicon-m-envelope'),

                Tables\Columns\TextColumn::make('school.is_suspended')
                    ->label('Statut de l\'école')
                    ->badge()
                    ->formatStateUsing(fn ($state): string => $state ? 'Suspendue' : 'Active')
                    ->color(fn ($state): string => $state ? 'danger' : 'success')
                    ->sortable(),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Date de création')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
            ])
            ->actions([
                Tables\Actions\EditAction::make()
                    ->label('Modifier'),

                Tables\Actions\Action::make('reset_password')
                    ->label('Réinitialiser mot de passe')
                    ->icon('heroicon-m-key')
                    ->color('warning')
                    ->requiresConfirmation()
                    ->modalHeading(fn (User $record) => "Réinitialiser mot de passe — {$record->email}")
                    ->modalDescription('Définissez un nouveau mot de passe simple pour ce directeur.')
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label('Nouveau mot de passe')
                            ->required()
                            ->minLength(6)
                            ->default(fn () => 'directeur' . random_int(100, 999))
                            ->helperText('Minimum 6 caractères. Mot de passe aléatoire prérempli.')
                            ->suffixAction(
                                Forms\Components\Actions\Action::make('generatePassword')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-o-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('new_password', 'directeur' . random_int(100, 999)))
                            ),
                    ])
                    ->action(function (User $record, array $data) {
                        $record->password = $data['new_password'];
                        $record->save();

                        session()->put('flash_director_credentials', [
                            'school_name' => $record->school?->name ?? 'École',
                            'login'       => $record->email,
                            'password'    => $data['new_password'],
                        ]);

                        Notification::make()
                            ->success()
                            ->title('Mot de passe directeur mis à jour')
                            ->body("Nouveau mot de passe pour {$record->email} : {$data['new_password']}")
                            ->persistent()
                            ->send();
                    }),

                Tables\Actions\DeleteAction::make()
                    ->label('Supprimer')
                    ->modalHeading('Supprimer ce directeur')
                    ->modalDescription('Êtes-vous sûr de vouloir supprimer ce compte directeur ?'),
            ])
            ->emptyStateHeading('Aucun directeur pour le moment')
            ->emptyStateDescription('Les comptes directeurs sont automatiquement créés lors de l\'ajout d\'une école, ou peuvent être créés ici.')
            ->emptyStateIcon('heroicon-o-user-circle')
            ->emptyStateActions([
                Tables\Actions\CreateAction::make()
                    ->label('Ajouter un directeur'),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index'  => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit'   => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
