<?php

declare(strict_types=1);

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
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
                Forms\Components\TextInput::make('name')
                    ->label('Nom complet')
                    ->required()
                    ->maxLength(255),

                Forms\Components\TextInput::make('phone')
                    ->label('Téléphone (+212...)')
                    ->required()
                    ->maxLength(255),

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

                Forms\Components\TextInput::make('password')
                    ->label('Mot de passe (optionnel pour parent SMS)')
                    ->password()
                    ->dehydrated(fn (?string $state): bool => filled($state))
                    ->maxLength(255),

                Forms\Components\Select::make('children')
                    ->label('Enfants rattachés (Fratrie)')
                    ->relationship('children', 'first_name')
                    ->multiple()
                    ->searchable()
                    ->preload(),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->label('Nom')
                    ->searchable()
                    ->sortable(),

                Tables\Columns\TextColumn::make('phone')
                    ->label('Téléphone')
                    ->searchable(),

                Tables\Columns\TextColumn::make('role')
                    ->label('Rôle')
                    ->badge()
                    ->sortable(),

                Tables\Columns\TextColumn::make('children.first_name')
                    ->label('Enfants rattachés')
                    ->badge(),

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
        return [
            //
        ];
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
