<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * AttendanceSubmission Model — SAMS-PACK-405
 *
 * Manages student attendance submissions, including submitted code,
 * submission time, GPS location, and attendance status.
 *
 * Attributes:
 *   - attendance_submission_id : int       — Primary key, unique submission identifier.
 *   - attendance_session_id    : int       — Foreign key to the attendance session.
 *   - student_id               : int       — Foreign key to the student (users).
 *   - submitted_code           : String    — The attendance code entered by the student.
 *   - submitted_at             : Timestamp — Timestamp when the submission was made.
 *   - gps_latitude             : Decimal   — Student's GPS latitude at time of submission.
 *   - gps_longitude            : Decimal   — Student's GPS longitude at time of submission.
 *   - attendance_status        : String    — Result: 'present' or 'rejected'.
 *   - created_at               : Timestamp — Record creation timestamp.
 *   - updated_at               : Timestamp — Record last update timestamp.
 */
class AttendanceSubmission extends Model
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

    protected $casts = [
        'gps_latitude'  => 'float',
        'gps_longitude' => 'float',
    ];

    // =========================================================================
    // SDD Methods — SAMS-PACK-405
    // =========================================================================

    /**
     * submitAttendance(attendance_session_id, student_id, submitted_code, gps_latitude, gps_longitude)
     *
     * Saves a new attendance submission record for a student.
     * Before saving, checks for duplicate submission — if the student has
     * already submitted for the same session, returns false.
     * Records the submitted code, current GPS coordinates, submission timestamp,
     * and sets attendance_status to 'present'.
     * Called from StudentAttendanceController::submitAttendance().
     *
     * @param  int    $sessionId     — The attendance session being submitted to.
     * @param  int    $studentId     — The student submitting attendance.
     * @param  string $submittedCode — The code entered by the student.
     * @param  float  $latitude      — Student's GPS latitude.
     * @param  float  $longitude     — Student's GPS longitude.
     * Returns: Boolean — true if submission was saved, false if duplicate exists.
     */
    public static function submitAttendance(
        int $sessionId,
        int $studentId,
        string $submittedCode,
        float $latitude,
        float $longitude
    ): bool {
        if (static::checkDuplicateSubmission($sessionId, $studentId)) {
            return false;
        }

        static::create([
            'attendance_session_id' => $sessionId,
            'student_id'            => $studentId,
            'submitted_code'        => $submittedCode,
            'submitted_at'          => now(),
            'gps_latitude'          => $latitude,
            'gps_longitude'         => $longitude,
            'attendance_status'     => 'present',
        ]);

        return true;
    }

    /**
     * checkDuplicateSubmission(attendance_session_id, student_id)
     *
     * Checks whether a student has already submitted attendance for a given session.
     * Prevents students from submitting more than once per session.
     * Called during the attendance submission flow before saving a new record.
     *
     * @param  int $sessionId — The attendance session ID to check.
     * @param  int $studentId — The student ID to check.
     * Returns: Boolean — true if a submission already exists, false otherwise.
     */
    public static function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return static::where('attendance_session_id', $sessionId)
            ->where('student_id', $studentId)
            ->exists();
    }

    /**
     * hasSubmitted(attendance_session_id, student_id)
     *
     * Alias for checkDuplicateSubmission(). Used in controllers to check
     * whether a student has already submitted attendance for the session.
     *
     * @param  int $sessionId — The attendance session ID.
     * @param  int $studentId — The student ID.
     * Returns: Boolean — true if submission exists, false otherwise.
     */
    public static function hasSubmitted(int $sessionId, int $studentId): bool
    {
        return static::checkDuplicateSubmission($sessionId, $studentId);
    }

    /**
     * getSubmissionsBySession(attendance_session_id)
     *
     * Retrieves all attendance submissions for a given session, including
     * the related student details for each submission.
     * Used by the lecturer to view live submissions and the attendance record.
     *
     * @param  int $sessionId — The attendance session ID to retrieve submissions for.
     * Returns: List<AttendanceSubmission> — All submissions with student data loaded.
     */
    public static function getSubmissionsBySession(int $sessionId)
    {
        return static::where('attendance_session_id', $sessionId)
            ->with('student')
            ->orderBy('submitted_at')
            ->get();
    }

    /**
     * countPresentStudents(attendance_session_id)
     *
     * Counts the number of students who are marked as 'present' for a session.
     * Used during report generation to calculate the present count summary.
     *
     * @param  int $sessionId — The attendance session ID to count for.
     * Returns: int — Total number of students with attendance_status = 'present'.
     */
    public static function countPresentStudents(int $sessionId): int
    {
        return static::where('attendance_session_id', $sessionId)
            ->where('attendance_status', 'present')
            ->count();
    }

    // =========================================================================
    // Eloquent Relationships
    // =========================================================================

    /**
     * Get the attendance session this submission belongs to.
     */
    public function session(): BelongsTo
    {
        return $this->belongsTo(AttendanceSession::class, 'attendance_session_id', 'attendance_session_id');
    }

    /**
     * Get the student who made this attendance submission.
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
