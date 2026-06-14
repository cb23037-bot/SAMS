<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * ClassSchedule — Entity Model
 * Requirement ID : SAMS-PACK-402
 * Responsibility : Manages scheduled class information, including lecturer, class reference,
 *                  course details, date, time, and venue.
 *
 * Attributes:
 *   schedule_id       int
 *   class_id          int
 *   lecturer_id       int
 *   course_code       String
 *   course_name       String
 *   class_name        String
 *   section           String
 *   semester          String
 *   academic_session  String
 *   day               String
 *   schedule_date     Date
 *   start_time        Time
 *   end_time          Time
 *   venue             String
 *   created_at        Timestamp
 *   updated_at        Timestamp
 */
class ClassSchedule extends Model
{
    protected $primaryKey = 'schedule_id';

    protected $fillable = [
        'class_id',
        'lecturer_id',
        'course_code',
        'course_name',
        'class_name',
        'section',
        'semester',
        'academic_session',
        'day',
        'schedule_date',
        'start_time',
        'end_time',
        'venue',
    ];

    protected $casts = [
        'schedule_date' => 'date',
    ];

    /**
     * getLecturerSchedules(lecturer_id) — List<ClassSchedule>
     * SAMS-PACK-402
     *
     * Retrieves all schedules assigned to the given lecturer, ordered by date and start time.
     * Each schedule is appended with its active session data (active_session key) so the
     * frontend can detect an ongoing session without a separate API call.
     *
     * Algorithm:
     *   FIND schedules WHERE lecturer_id = lecturer_id
     *   FOR each schedule → appendActiveSession(schedule)
     *   RETURN schedule list
     */
    public static function getLecturerSchedules(int $lecturerId): \Illuminate\Support\Collection
    {
        $schedules = self::where('lecturer_id', $lecturerId)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();

        return $schedules->map(fn($s) => self::appendActiveSession($s));
    }

    /**
     * getTodaySchedule(lecturer_id) — List<ClassSchedule>
     * SAMS-PACK-402
     *
     * Retrieves lecturer's schedules for the current date only.
     * Also appends active session data per schedule.
     *
     * Algorithm:
     *   FIND schedules WHERE lecturer_id = lecturer_id AND schedule_date = current_date
     *   IF schedules found THEN RETURN schedules ELSE RETURN empty list
     */
    public static function getTodaySchedule(int $lecturerId): \Illuminate\Support\Collection
    {
        $schedules = self::where('lecturer_id', $lecturerId)
            ->whereDate('schedule_date', today())
            ->orderBy('start_time')
            ->get();

        return $schedules->map(fn($s) => self::appendActiveSession($s));
    }

    /**
     * validateSchedule(schedule_id) — Boolean
     * SAMS-PACK-402
     *
     * Checks whether a schedule with the given ID exists in the database.
     *
     * Algorithm:
     *   FIND schedule by schedule_id
     *   IF schedule found THEN RETURN true ELSE RETURN false
     */
    public static function validateSchedule(int $scheduleId): bool
    {
        return self::where('schedule_id', $scheduleId)->exists();
    }

    /**
     * verifyLecturerSchedule(schedule_id, lecturer_id) — Boolean
     * SAMS-PACK-402
     *
     * Checks whether the lecturer owns (is assigned to) the given schedule.
     *
     * Algorithm:
     *   FIND schedule by schedule_id
     *   IF schedule.lecturer_id = lecturer_id THEN RETURN true ELSE RETURN false
     */
    public static function verifyLecturerSchedule(int $scheduleId, int $lecturerId): bool
    {
        return self::where('schedule_id', $scheduleId)
            ->where('lecturer_id', $lecturerId)
            ->exists();
    }

    /**
     * appendActiveSession(schedule) — array
     *
     * Helper: converts a ClassSchedule model to an array and attaches the active
     * AttendanceSession (if any) under the 'active_session' key.
     * This allows the Flutter frontend to detect and navigate to an active session
     * directly from the schedule list without an extra API call.
     */
    private static function appendActiveSession(self $schedule): array
    {
        $data = $schedule->toArray();
        $active = AttendanceSession::getActiveSession($schedule->schedule_id);
        $data['active_session'] = $active ? $active->toArray() : null;
        return $data;
    }

    // ── Relationships ────────────────────────────────────────────────────────

    public function lecturer()
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    public function attendanceSessions()
    {
        return $this->hasMany(AttendanceSession::class, 'schedule_id', 'schedule_id');
    }

    public function enrollments()
    {
        return $this->hasMany(ClassEnrollment::class, 'schedule_id', 'schedule_id');
    }
}
