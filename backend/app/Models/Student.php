<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Student extends Model
{
    protected $fillable = ['user_id', 'matric_number', 'program_code', 'current_semester'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function fees(): HasMany
    {
        return $this->hasMany(Fee::class)->orderByDesc('created_at');
    }

    public function restrictions(): HasMany
    {
        return $this->hasMany(Restriction::class)->orderByDesc('applied_date');
    }
}
