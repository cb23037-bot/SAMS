<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

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

    /**
     * The lecturer assigned to this class schedule.
     */
    public function lecturer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'lecturer_id');
    }

    /**
     * Attendance sessions opened for this schedule.
     */
    public function attendanceSessions(): HasMany
    {
        return $this->hasMany(AttendanceSession::class, 'schedule_id', 'schedule_id');
    }

    /**
     * Students enrolled in this schedule's class.
     */
    public function enrollments(): HasMany
    {
        return $this->hasMany(ClassEnrollment::class, 'class_id', 'class_id');
    }

    /**
     * Get all schedules assigned to a given lecturer.
     */
    public static function getLecturerSchedules(int $lecturerId)
    {
        return static::where('lecturer_id', $lecturerId)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();
    }

    /**
     * Get a lecturer's schedules for today only.
     */
    public static function getTodaySchedules(int $lecturerId)
    {
        return static::where('lecturer_id', $lecturerId)
            ->whereDate('schedule_date', now()->toDateString())
            ->orderBy('start_time')
            ->get();
    }

    /**
     * Count the number of students currently enrolled in this schedule's class.
     */
    public function countEnrolledStudents(): int
    {
        return ClassEnrollment::where('class_id', $this->class_id)
            ->where('status', 'enrolled')
            ->count();
    }
}
