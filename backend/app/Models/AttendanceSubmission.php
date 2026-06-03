<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AttendanceSubmission extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'activity_slot_id',
        'attendance_code_submitted',
        'photo_path',
        'latitude',
        'longitude',
        'address',
        'receipt_id',
        'receipt_hash',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function slot(): BelongsTo
    {
        return $this->belongsTo(ActivitySlot::class, 'activity_slot_id');
    }
}
