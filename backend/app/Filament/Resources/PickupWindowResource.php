<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PickupWindowResource\Pages;
use App\Filament\Resources\PickupWindowResource\RelationManagers;
use App\Models\PickupWindow;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\SoftDeletingScope;

class PickupWindowResource extends Resource
{
    protected static ?string $model = PickupWindow::class;

    protected static ?string $navigationIcon = 'heroicon-o-clock';

    protected static ?string $navigationLabel = 'Fenêtres de sortie';

    protected static ?string $modelLabel = 'Fenêtre de sortie';

    protected static ?string $pluralModelLabel = 'Fenêtres de sortie';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Select::make('day_of_week')
                    ->options([
                        1 => 'Lundi',
                        2 => 'Mardi',
                        3 => 'Mercredi',
                        4 => 'Jeudi',
                        5 => 'Vendredi',
                        6 => 'Samedi',
                        7 => 'Dimanche',
                    ])
                    ->required()
                    ->label('Jour de la semaine'),
                Forms\Components\TimePicker::make('start_time')
                    ->required()
                    ->label('Heure de début'),
                Forms\Components\TimePicker::make('end_time')
                    ->required()
                    ->label('Heure de fin'),
                Forms\Components\Toggle::make('is_ramadan')
                    ->label('Régime horaire Ramadan'),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('day_of_week')
                    ->formatStateUsing(fn ($state) => match ((int) $state) {
                        1 => 'Lundi',
                        2 => 'Mardi',
                        3 => 'Mercredi',
                        4 => 'Jeudi',
                        5 => 'Vendredi',
                        6 => 'Samedi',
                        7 => 'Dimanche',
                        default => (string) $state,
                    })
                    ->sortable()
                    ->label('Jour'),
                Tables\Columns\TextColumn::make('start_time')
                    ->sortable()
                    ->label('Début'),
                Tables\Columns\TextColumn::make('end_time')
                    ->sortable()
                    ->label('Fin'),
                Tables\Columns\IconColumn::make('is_ramadan')
                    ->boolean()
                    ->label('Ramadan'),
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                //
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
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
            'index' => Pages\ListPickupWindows::route('/'),
            'create' => Pages\CreatePickupWindow::route('/create'),
            'edit' => Pages\EditPickupWindow::route('/{record}/edit'),
        ];
    }
}
