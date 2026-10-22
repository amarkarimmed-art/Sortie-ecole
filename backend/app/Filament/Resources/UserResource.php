<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Components\Actions\Action as FormAction;
use Filament\Forms\Components\Section;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationLabel = 'Parents & Personnel';

    protected static ?string $modelLabel = 'Membre / Parent';

    protected static ?string $pluralModelLabel = 'Parents & Personnel';

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->whereIn('role', ['parent', 'surveillant', 'concierge']);
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make()
                    ->columns(1)
                    ->maxWidth('xl')
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->label('Nom complet')
                            ->required()
                            ->maxLength(255),

                        Forms\Components\TextInput::make('email')
                            ->label('Login')
                            ->required()
                            ->maxLength(255)
                            ->unique(User::class, 'email', ignoreRecord: true)
                            ->helperText('Identifiant unique de connexion (ex. parent.oussama@alamal).'),

                        Forms\Components\TextInput::make('password')
                            ->label('Mot de passe')
                            ->minLength(6)
                            ->required(fn (string $operation): bool => $operation === 'create')
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->helperText('6 caractères minimum, sans règle de complexité.')
                            ->suffixAction(
                                FormAction::make('generatePassword')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-m-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('password', 'sortie' . random_int(1000, 9999)))
                            ),

                        Forms\Components\Select::make('role')
                            ->label('Rôle')
                            ->options([
                                'parent'      => 'Parent',
                                'surveillant' => 'Surveillant',
                                'concierge'   => 'Concierge',
                            ])
                            ->default('parent')
                            ->required()
                            ->live(),

                        Forms\Components\TextInput::make('phone')
                            ->label('Téléphone (facultatif)')
                            ->nullable()
                            ->maxLength(255)
                            ->helperText('Facultatif — jamais utilisé pour se connecter.'),

                        Forms\Components\Select::make('children')
                            ->label('Enfants rattachés (Fratrie)')
                            ->relationship('children', 'first_name')
                            ->multiple()
                            ->searchable()
                            ->preload()
                            ->visible(fn (Forms\Get $get): bool => $get('role') === 'parent' || empty($get('role'))),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Nom complet')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('email')
                    ->label('Login')
                    ->searchable()
                    ->copyable(),

                Tables\Columns\TextColumn::make('role')
                    ->label('Rôle')
                    ->badge()
                    ->sortable(),

                Tables\Columns\TextColumn::make('children.first_name')
                    ->label('Enfants rattachés')
                    ->badge(),

                Tables\Columns\TextColumn::make('phone')
                    ->label('Téléphone')
                    ->toggleable(isToggledHiddenByDefault: true),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Date de création')
                    ->dateTime('d/m/Y H:i')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('role')
                    ->label('Rôle')
                    ->options([
                        'parent'      => 'Parent',
                        'surveillant' => 'Surveillant',
                        'concierge'   => 'Concierge',
                    ]),
            ])
            ->actions([
                Tables\Actions\Action::make('reset_password')
                    ->label('Réinitialiser le mot de passe')
                    ->icon('heroicon-o-key')
                    ->requiresConfirmation()
                    ->form([
                        Forms\Components\TextInput::make('new_password')
                            ->label('Nouveau mot de passe')
                            ->default(fn () => 'sortie' . random_int(1000, 9999))
                            ->minLength(6)
                            ->required()
                            ->suffixAction(
                                FormAction::make('generateSimple')
                                    ->label('Générer un mot de passe simple')
                                    ->icon('heroicon-m-sparkles')
                                    ->action(fn (Forms\Set $set) => $set('new_password', 'sortie' . random_int(1000, 9999)))
                            ),
                    ])
                    ->action(function (User $record, array $data) {
                        $record->password = $data['new_password'];
                        $record->save();

                        session()->put('flash_director_credentials', [
                            'school_name' => auth()->user()?->school?->name ?? '',
                            'login'       => $record->email,
                            'password'    => $data['new_password'],
                        ]);

                        Notification::make()
                            ->title('Mot de passe réinitialisé')
                            ->body("Nouveau mot de passe pour {$record->email} : {$data['new_password']}")
                            ->success()
                            ->send();
                    }),

                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
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
