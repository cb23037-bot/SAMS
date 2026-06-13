<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// SAMS-PACK-405
class AttendanceSubmission extends Model
{
    protected $primaryKey = 'attendance_submission_id';

    protected $fillable = [
        'attendance_session_id', 'student_id', 'submitted_code',
        'submitted_at', 'gps_latitude', 'gps_longitude', 'attendance_status',
    ];

    protected $casts = [
        'submitted_at'  => 'datetime',
        'gps_latitude'  => 'float',
        'gps_longitude' => 'float',
    ];

    // SAMS-PACK-405: submitAttendance(...)
    public static function submitAttendance(
        int $sessionId, int $studentId, string $code,
        float $lat, float $lng
    ): self|string {
        if (self::checkDuplicateSubmission($sessionId, $studentId)) {
            return 'Attendance has already been submitted';
        }
        return self::create([
            'attendance_session_id' => $sessionId,
            'student_id'            => $studentId,
            'submitted_code'        => strtoupper($code),
            'submitted_at'          => now(),
            'gps_latitude'          => $lat,
            'gps_longitude'         => $lng,
            'attendance_status'     => 'present',
        ]);
    }

    // SAMS-PACK-405: checkDuplicateSubmission(session_id, student_id)
    public static function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return self::where('attendance_session_id', $sessionId)
            ->where('student_id', $studentId)
            ->exists();
    }

    // SAMS-PACK-405: getSubmissionsBySession(attendance_session_id)
    public static function getSubmissionsBySession(int $sessionId): \Illuminate\Database\Eloquent\Collection
    {
        return self::with('student:id,name,student_id,course')
            ->where('attendance_session_id', $sessionId)
            ->orderBy('submitted_at')
            ->get();
    }

    // SAMS-PACK-405: countPresentStudents(attendance_session_id)
    public static function countPresentStudents(int $sessionId): int
    {
        return self::where('attendance_session_id', $sessionId)
            ->where('attendance_status', 'present')
            ->count();
    }

    // Relationships
    public function session()
    {
        return $this->belongsTo(AttendanceSession::class, 'attendance_session_id', 'attendance_session_id');
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
