<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClassAttendanceSubmission extends Model
{
    protected $table = 'class_attendance_submissions';

    protected $primaryKey = 'attendance_submission_id';

    protected $fillable = [
        'attendance_session_id',
        'student_id',
        'submitted_code',
        'submitted_at',
        'gps_latitude',
        'gps_longitude',
        'attendance_status',
    ];

    /**
     * The attendance session this submission belongs to.
     */
    public function session(): BelongsTo
    {
        return $this->belongsTo(AttendanceSession::class, 'attendance_session_id', 'attendance_session_id');
    }

    /**
     * The student who submitted this attendance record.
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * Check whether a student has already submitted attendance for a session.
     */
    public static function hasSubmitted(int $sessionId, int $studentId): bool
    {
        return static::where('attendance_session_id', $sessionId)
            ->where('student_id', $studentId)
            ->exists();
    }
}
