<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * ClassSchedule Model — SAMS-PACK-402
 *
 * Manages scheduled class information, including lecturer, class reference,
 * course details, date, time, and venue.
 *
 * Attributes:
 *   - schedule_id      : int       — Primary key, unique schedule identifier.
 *   - class_id         : int       — Reference to the class group.
 *   - lecturer_id      : int       — Foreign key to the assigned lecturer (users).
 *   - course_code      : String    — Course code (e.g. 'CSC3103').
 *   - course_name      : String    — Full name of the course.
 *   - class_name       : String    — Class group name.
 *   - section          : String    — Section identifier (e.g. 'A', 'B').
 *   - semester         : String    — Semester (e.g. '1', '2').
 *   - academic_session : String    — Academic session (e.g. '2024/2025').
 *   - day              : String    — Day of the week the class is held.
 *   - schedule_date    : Date      — Specific date of the class.
 *   - start_time       : Time      — Class start time.
 *   - end_time         : Time      — Class end time.
 *   - venue            : String    — Location or room of the class.
 *   - created_at       : Timestamp — Record creation timestamp.
 *   - updated_at       : Timestamp — Record last update timestamp.
 */
class ClassSchedule extends Model
{
    protected $table = 'class_schedules';

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

    // =========================================================================
    // SDD Methods — SAMS-PACK-402
    // =========================================================================

    /**
     * getLecturerSchedules(lecturer_id)
     *
     * Retrieves all class schedules assigned to the given lecturer.
     * Results are ordered by schedule date and start time for display.
     *
     * @param  int $lecturerId — The ID of the lecturer.
     * Returns: List<ClassSchedule> — All schedules belonging to the lecturer.
     */
    public static function getLecturerSchedules(int $lecturerId)
    {
        return static::where('lecturer_id', $lecturerId)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();
    }

    /**
     * getTodaySchedule(lecturer_id, current_date)
     *
     * Retrieves the lecturer's class schedules for today's date only.
     * Used by the dashboard to show which classes are happening today.
     *
     * @param  int $lecturerId — The ID of the lecturer.
     * Returns: List<ClassSchedule> — Schedules matching today's date, or empty list.
     */
    public static function getTodaySchedules(int $lecturerId)
    {
        return static::where('lecturer_id', $lecturerId)
            ->whereDate('schedule_date', now()->toDateString())
            ->orderBy('start_time')
            ->get();
    }

    /**
     * validateSchedule(schedule_id)
     *
     * Checks whether a class schedule exists in the system for the given ID.
     * Used to confirm the selected schedule is valid before starting a session.
     *
     * @param  int $scheduleId — The schedule ID to validate.
     * Returns: Boolean — true if the schedule exists, false otherwise.
     */
    public static function validateSchedule(int $scheduleId): bool
    {
        return static::where('schedule_id', $scheduleId)->exists();
    }

    /**
     * verifyLecturerSchedule(schedule_id, lecturer_id)
     *
     * Checks whether the given lecturer is the owner of the specified schedule.
     * Prevents lecturers from starting or closing sessions for other lecturers' classes.
     *
     * @param  int $scheduleId  — The schedule ID to check.
     * @param  int $lecturerId  — The lecturer ID to verify ownership against.
     * Returns: Boolean — true if the schedule belongs to the lecturer, false otherwise.
     */
    public static function verifyLecturerSchedule(int $scheduleId, int $lecturerId): bool
    {
        return static::where('schedule_id', $scheduleId)
            ->where('lecturer_id', $lecturerId)
            ->exists();
    }

    /**
     * countEnrolledStudents()
     *
     * Returns the number of students currently enrolled in this schedule's class.
     * Used to display enrollment count on the lecturer's class list and live session.
     *
     * Returns: int — Total enrolled student count with status 'enrolled'.
     */
    public function countEnrolledStudents(): int
    {
        return ClassEnrollment::where('class_id', $this->class_id)
            ->where('status', 'enrolled')
            ->count();
    }

    // =========================================================================
    // Eloquent Relationships
    // =========================================================================

    /**
     * Get the lecturer assigned to this class schedule.
     */
    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    /**
     * Get all attendance sessions opened for this schedule.
     */
    public function attendanceSessions(): HasMany
    {
        return $this->hasMany(AttendanceSession::class, 'schedule_id', 'schedule_id');
    }

    /**
     * Get all student enrollments for this schedule's class.
     */
    public function enrollments(): HasMany
    {
        return $this->hasMany(ClassEnrollment::class, 'class_id', 'class_id');
    }
}
