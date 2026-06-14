<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * AttendanceSubmission — Entity Model
 * Requirement ID : SAMS-PACK-405
 * Responsibility : Manages student attendance submissions, including submitted code,
 *                  submission time, GPS location, and attendance status.
 *
 * Attributes:
 *   attendance_submission_id  int
 *   attendance_session_id     int
 *   student_id                int
 *   submitted_code            String
 *   submitted_at              Timestamp
 *   gps_latitude              Decimal
 *   gps_longitude             Decimal
 *   attendance_status         String
 *   created_at                Timestamp
 *   updated_at                Timestamp
 */
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

    /**
     * submitAttendance(attendance_session_id, student_id, submitted_code, gps_latitude, gps_longitude) — Boolean
     * SAMS-PACK-405
     *
     * Saves an attendance submission record for the student.
     * Returns an error string if the student has already submitted for this session.
     *
     * Algorithm:
     *   CHECK duplicate submission WHERE attendance_session_id AND student_id match
     *   IF duplicate exists THEN RETURN error "Attendance has already been submitted"
     *   ELSE CREATE new submission with attendance_status = "present" → RETURN record
     */
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

    /**
     * checkDuplicateSubmission(attendance_session_id, student_id) — Boolean
     * SAMS-PACK-405
     *
     * Checks whether the student has already submitted attendance for this session.
     *
     * Algorithm:
     *   FIND submission WHERE attendance_session_id AND student_id match
     *   IF submission found THEN RETURN true ELSE RETURN false
     */
    public static function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return self::where('attendance_session_id', $sessionId)
            ->where('student_id', $studentId)
            ->exists();
    }

    /**
     * getSubmissionsBySession(attendance_session_id) — List<AttendanceSubmission>
     * SAMS-PACK-405
     *
     * Retrieves all submissions for a session, with student details eager-loaded.
     * Used by both live session monitoring and attendance record views.
     *
     * Algorithm:
     *   FIND submissions WHERE attendance_session_id = attendance_session_id
     *   FETCH student details
     *   RETURN submission list ordered by submitted_at
     */
    public static function getSubmissionsBySession(int $sessionId): \Illuminate\Database\Eloquent\Collection
    {
        return self::with('student:id,name,student_id,course')
            ->where('attendance_session_id', $sessionId)
            ->orderBy('submitted_at')
            ->get();
    }

    /**
     * countPresentStudents(attendance_session_id) — int
     * SAMS-PACK-405
     *
     * Counts the number of students with attendance_status = "present" for a session.
     * Used by the report controller to calculate summary statistics.
     *
     * Algorithm:
     *   COUNT submissions WHERE attendance_session_id = attendance_session_id
     *   AND attendance_status = "present"
     *   RETURN present_students count
     */
    public static function countPresentStudents(int $sessionId): int
    {
        return self::where('attendance_session_id', $sessionId)
            ->where('attendance_status', 'present')
            ->count();
    }

    // ── Relationships ────────────────────────────────────────────────────────

    public function session()
    {
        return $this->belongsTo(AttendanceSession::class, 'attendance_session_id', 'attendance_session_id');
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
