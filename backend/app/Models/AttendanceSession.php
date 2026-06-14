<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * AttendanceSession — Entity Model
 * Requirement ID : SAMS-PACK-404
 * Responsibility : Manages lecturer-created attendance sessions, generated attendance code,
 *                  session status, start time, close time, and GPS boundary used.
 *
 * Attributes:
 *   attendance_session_id  int
 *   schedule_id            int
 *   lecturer_id            int
 *   campus_boundary_id     int
 *   attendance_code        String
 *   session_date           Date
 *   started_at             Timestamp
 *   closed_at              Timestamp
 *   status                 String
 *   created_at             Timestamp
 */
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

    /**
     * createSession(schedule_id, lecturer_id, campus_boundary_id) — AttendanceSession
     * SAMS-PACK-404
     *
     * Creates a new active attendance session for the given schedule.
     * Returns an error string if an active session already exists (SAMS-REQ-425).
     *
     * Algorithm:
     *   CHECK active session WHERE schedule_id = schedule_id AND status = "active"
     *   IF active session exists THEN
     *     RETURN error "An attendance session is already active for this class"
     *   ELSE
     *     CREATE new attendance session with generated code
     *     SET session_date = current_date, started_at = current_timestamp, status = "active"
     *     RETURN attendance session
     */
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

    /**
     * generateCode(attendance_session_id) — String|false
     * SAMS-PACK-404
     *
     * Generates a new unique attendance code for an active session.
     * Returns false if the session is not active.
     *
     * Algorithm:
     *   IF session.status != "active" THEN RETURN false
     *   GENERATE random attendance code
     *   WHILE attendance code already exists DO GENERATE new code
     *   UPDATE session.attendance_code = generated_code
     *   SAVE session → RETURN generated_code
     */
    public function generateCode(): string|false
    {
        if ($this->status !== 'active') return false;
        $code = self::generateUniqueCode();
        $this->attendance_code = $code;
        $this->save();
        return $code;
    }

    /**
     * getActiveSession(schedule_id) — AttendanceSession|null
     * SAMS-PACK-404
     *
     * Retrieves the currently active attendance session for a given schedule.
     * Returns null if no active session exists.
     *
     * Algorithm:
     *   FIND attendance session WHERE schedule_id = schedule_id AND status = "active"
     *   IF session found THEN RETURN session ELSE RETURN null
     */
    public static function getActiveSession(int $scheduleId): ?self
    {
        return self::where('schedule_id', $scheduleId)->where('status', 'active')->first();
    }

    /**
     * verifySessionStatus(attendance_session_id) — Boolean
     * SAMS-PACK-404
     *
     * Checks whether the given session is currently active.
     *
     * Algorithm:
     *   FIND session by attendance_session_id
     *   IF session found AND session.status = "active" THEN RETURN true ELSE RETURN false
     */
    public static function verifySessionStatus(int $sessionId): bool
    {
        $session = self::find($sessionId);
        return $session && $session->status === 'active';
    }

    /**
     * closeSession(attendance_session_id) — Boolean
     * SAMS-PACK-404
     *
     * Closes an active attendance session by setting status to "closed" and recording closed_at.
     *
     * Algorithm:
     *   FIND attendance session by attendance_session_id
     *   IF session found AND session.status = "active" THEN
     *     UPDATE session.status = "closed"
     *     UPDATE session.closed_at = current_timestamp
     *     SAVE session → RETURN true
     *   ELSE RETURN false
     */
    public static function closeSession(int $sessionId): bool
    {
        $session = self::find($sessionId);
        if (!$session || $session->status !== 'active') return false;
        $session->status    = 'closed';
        $session->closed_at = now();
        return $session->save();
    }

    /**
     * generateUniqueCode() — String
     *
     * Generates a unique 6-character uppercase alphanumeric code.
     * Loops until a code not already in use is found.
     */
    private static function generateUniqueCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (self::where('attendance_code', $code)->exists());
        return $code;
    }

    // ── Relationships ────────────────────────────────────────────────────────

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
