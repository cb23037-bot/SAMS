<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

// SAMS-PACK-404
class AttendanceSession extends Model
{
    protected $primaryKey = 'attendance_session_id';

    protected $fillable = [
        'class_id', 'schedule_id', 'lecturer_id', 'campus_boundary_id',
        'attendance_code', 'session_date', 'started_at', 'closed_at', 'status',
    ];

    protected $casts = [
        'session_date' => 'date',
        'started_at'   => 'datetime',
        'closed_at'    => 'datetime',
    ];

    // SAMS-PACK-404: createSession(schedule_id, lecturer_id, campus_boundary_id)
    public static function createSession(int $scheduleId, int $lecturerId, int $boundaryId): self|string
    {
        $existing = self::where('schedule_id', $scheduleId)->where('status', 'active')->first();
        if ($existing) {
            return 'An attendance session is already active for this class';
        }

        $schedule = ClassSchedule::find($scheduleId);
        $code     = self::generateUniqueCode();

        return self::create([
            'class_id'           => $schedule->class_id,
            'schedule_id'        => $scheduleId,
            'lecturer_id'        => $lecturerId,
            'campus_boundary_id' => $boundaryId,
            'attendance_code'    => $code,
            'session_date'       => today(),
            'started_at'         => now(),
            'status'             => 'active',
        ]);
    }

    // SAMS-PACK-404: generateCode(attendance_session_id)
    public function generateCode(): string|false
    {
        if ($this->status !== 'active') return false;
        $code = self::generateUniqueCode();
        $this->attendance_code = $code;
        $this->save();
        return $code;
    }

    // SAMS-PACK-404: getActiveSession(schedule_id)
    public static function getActiveSession(int $scheduleId): ?self
    {
        return self::where('schedule_id', $scheduleId)->where('status', 'active')->first();
    }

    // SAMS-PACK-404: verifySessionStatus(attendance_session_id)
    public static function verifySessionStatus(int $sessionId): bool
    {
        $session = self::find($sessionId);
        return $session && $session->status === 'active';
    }

    // SAMS-PACK-404: closeSession(attendance_session_id)
    public static function closeSession(int $sessionId): bool
    {
        $session = self::find($sessionId);
        if (!$session || $session->status !== 'active') return false;
        $session->status    = 'closed';
        $session->closed_at = now();
        return $session->save();
    }

    // Generate a unique 6-character alphanumeric code
    private static function generateUniqueCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (self::where('attendance_code', $code)->exists());
        return $code;
    }

    // Relationships
    public function schedule()
    {
        return $this->belongsTo(ClassSchedule::class, 'schedule_id', 'schedule_id');
    }

    public function lecturer()
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    public function boundary()
    {
        return $this->belongsTo(CampusBoundary::class, 'campus_boundary_id', 'campus_boundary_id');
    }

    public function submissions()
    {
        return $this->hasMany(AttendanceSubmission::class, 'attendance_session_id', 'attendance_session_id');
    }
}
