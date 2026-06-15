<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

/**
 * AttendanceSession Model — SAMS-PACK-404
 *
 * Manages lecturer-created attendance sessions, generated attendance code,
 * session status, start time, close time, and GPS boundary used.
 *
 * Attributes:
 *   - attendance_session_id : int       — Primary key, unique session identifier.
 *   - schedule_id           : int       — Foreign key to the class schedule.
 *   - lecturer_id           : int       — Foreign key to the lecturer who created the session.
 *   - campus_boundary_id    : int       — Foreign key to the campus boundary used for GPS check.
 *   - attendance_code       : String    — Unique code students enter to submit attendance.
 *   - session_date          : Date      — The date the session was held.
 *   - started_at            : Timestamp — Timestamp when the session was started.
 *   - closed_at             : Timestamp — Timestamp when the session was closed.
 *   - status                : String    — Session status: 'active' or 'closed'.
 *   - created_at            : Timestamp — Record creation timestamp.
 */
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

    // =========================================================================
    // SDD Methods — SAMS-PACK-404
    // =========================================================================

    /**
     * createSession(schedule_id, lecturer_id, campus_boundary_id)
     *
     * Creates a new active attendance session for a class schedule.
     * Before creating, checks whether an active session already exists for
     * the class — if so, returns the existing session with an error flag.
     * Sets session_date to today, started_at to current timestamp, and
     * status to 'active'. Called from LecturerAttendanceController::startSession().
     *
     * @param  int $scheduleId       — The schedule to create a session for.
     * @param  int $lecturerId       — The lecturer creating the session.
     * @param  int $campusBoundaryId — The active campus boundary to enforce.
     * Returns: AttendanceSession — The newly created session record.
     */
    public static function createSession(int $scheduleId, int $lecturerId, int $campusBoundaryId): self
    {
        $schedule = ClassSchedule::where('schedule_id', $scheduleId)->firstOrFail();

        return static::create([
            'class_id'           => $schedule->class_id,
            'schedule_id'        => $scheduleId,
            'lecturer_id'        => $lecturerId,
            'campus_boundary_id' => $campusBoundaryId,
            'attendance_code'    => static::generateCode(),
            'session_date'       => now()->toDateString(),
            'started_at'         => now(),
            'status'             => 'active',
        ]);
    }

    /**
     * generateCode(attendance_session_id)
     *
     * Generates a random unique 6-character uppercase attendance code.
     * Keeps regenerating until a code is found that does not already exist
     * in the attendance_sessions table, ensuring global uniqueness.
     * Called when starting a session or when the lecturer requests a new code.
     *
     * Returns: String — A unique 6-character attendance code.
     */
    public static function generateCode(): string
    {
        do {
            $code = strtoupper(Str::random(6));
        } while (static::where('attendance_code', $code)->exists());

        return $code;
    }

    /**
     * getActiveSession(schedule_id)
     *
     * Retrieves the currently active attendance session for a given class schedule.
     * Looks up the class_id from the schedule, then finds the latest active session
     * for that class. Returns null if no active session exists.
     * Used by both lecturer and student flows to check session availability.
     *
     * @param  int $scheduleId — The schedule ID to look up the active session for.
     * Returns: AttendanceSession — The active session, or null if none exists.
     */
    public static function getActiveSession(int $scheduleId): ?self
    {
        $schedule = ClassSchedule::where('schedule_id', $scheduleId)->first();

        if (!$schedule) {
            return null;
        }

        return static::where('class_id', $schedule->class_id)
            ->where('status', 'active')
            ->latest('started_at')
            ->first();
    }

    /**
     * getActiveSessionForClass(class_id)
     *
     * Retrieves the currently active attendance session directly by class_id.
     * Used internally when the class_id is already known (e.g. from enrollment lookup).
     *
     * @param  int $classId — The class ID to find the active session for.
     * Returns: AttendanceSession — The active session, or null if none exists.
     */
    public static function getActiveSessionForClass(int $classId): ?self
    {
        return static::where('class_id', $classId)
            ->where('status', 'active')
            ->latest('started_at')
            ->first();
    }

    /**
     * verifySessionStatus(attendance_session_id)
     *
     * Checks whether the given attendance session is currently active.
     * Used before allowing students to submit attendance — if the session
     * is closed or does not exist, submission is rejected.
     *
     * @param  int $sessionId — The attendance session ID to check.
     * Returns: Boolean — true if the session exists and its status is 'active'.
     */
    public static function verifySessionStatus(int $sessionId): bool
    {
        return static::where('attendance_session_id', $sessionId)
            ->where('status', 'active')
            ->exists();
    }

    /**
     * closeSession(attendance_session_id)
     *
     * Closes this active attendance session by setting its status to 'closed'
     * and recording the exact timestamp it was closed.
     * After this, students can no longer submit attendance for the session.
     * Called when the lecturer clicks "Close Attendance Session".
     *
     * Returns: void
     */
    public function closeSession(): void
    {
        $this->status    = 'closed';
        $this->closed_at = now();
        $this->save();
    }

    // =========================================================================
    // Eloquent Relationships
    // =========================================================================

    /**
     * Get the class schedule this session was created for.
     */
    public function schedule(): BelongsTo
    {
        return $this->belongsTo(ClassSchedule::class, 'schedule_id', 'schedule_id');
    }

    /**
     * Get the lecturer who started this attendance session.
     */
    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    /**
     * Get the campus boundary used for GPS verification in this session.
     */
    public function campusBoundary(): BelongsTo
    {
        return $this->belongsTo(CampusBoundary::class, 'campus_boundary_id', 'campus_boundary_id');
    }

    /**
     * Get all student attendance submissions recorded for this session.
     */
    public function submissions(): HasMany
    {
        return $this->hasMany(AttendanceSubmission::class, 'attendance_session_id', 'attendance_session_id');
    }
}
