<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Modèle Classe scolaire (SchoolClass).
 * Applique l'isolation multi-école (ADR 0005) via BaseModel.
 */
class SchoolClass extends BaseModel
{
    use HasFactory;

    protected $guarded = ['id'];

    public function children(): HasMany
    {
        return $this->hasMany(Child::class, 'class_name', 'name');
    }

    public function surveillants(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'school_class_user')->withTimestamps();
    }
}
