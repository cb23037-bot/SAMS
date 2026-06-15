<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class AttendanceSession extends Model
{
    protected $table = 'attendance_sessions';

    protected $primaryKey = 'attendance_session_id';

    protected $fillable = [
        'class_id',
        'schedule_id',
        'lecturer_id',
        'campus_boundary_id',
        'attendance_code',
        'session_date',
        'started_at',
        'closed_at',
        'status',
    ];

    /**
     * The class schedule this session belongs to.
     */
    public function schedule(): BelongsTo
    {
        return $this->belongsTo(ClassSchedule::class, 'schedule_id', 'schedule_id');
    }

    /**
     * The lecturer who started this session.
     */
    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    /**
     * The campus boundary used to verify attendance for this session.
     */
    public function campusBoundary(): BelongsTo
    {
        return $this->belongsTo(CampusBoundary::class, 'campus_boundary_id', 'campus_boundary_id');
    }

    /**
     * Student submissions recorded for this session.
     */
    public function submissions(): HasMany
    {
        return $this->hasMany(ClassAttendanceSubmission::class, 'attendance_session_id', 'attendance_session_id');
    }

    /**
     * Generate a unique random attendance code.
     */
    public static function generateCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (static::where('attendance_code', $code)->exists());

        return $code;
    }

    /**
     * Get the active attendance session for a given class, if any.
     */
    public static function getActiveSessionForClass(int $classId): ?self
    {
        return static::where('class_id', $classId)
            ->where('status', 'active')
            ->latest('started_at')
            ->first();
    }

    /**
     * Close this attendance session.
     */
    public function closeSession(): void
    {
        $this->status = 'closed';
        $this->closed_at = now();
        $this->save();
    }
}
