<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ActivitySlot extends Model
{
    use HasFactory;

    protected $fillable = ['activity_id', 'date', 'time', 'capacity', 'registered', 'attendance_code'];

    protected $casts = ['date' => 'date'];

    public function activity(): BelongsTo
    {
        return $this->belongsTo(Activity::class);
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(ActivityRegistration::class, 'activity_slot_id');
    }
}
