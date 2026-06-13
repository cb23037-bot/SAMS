<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

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

    // SAMS-PACK-402: getLecturerSchedules(lecturer_id)
    public static function getLecturerSchedules(int $lecturerId): \Illuminate\Database\Eloquent\Collection
    {
        return self::where('lecturer_id', $lecturerId)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();
    }

    // SAMS-PACK-402: getTodaySchedule(lecturer_id, current_date)
    public static function getTodaySchedule(int $lecturerId): \Illuminate\Database\Eloquent\Collection
    {
        return self::where('lecturer_id', $lecturerId)
            ->whereDate('schedule_date', today())
            ->orderBy('start_time')
            ->get();
    }

    // SAMS-PACK-402: validateSchedule(schedule_id)
    public static function validateSchedule(int $scheduleId): bool
    {
        return self::where('schedule_id', $scheduleId)->exists();
    }

    // SAMS-PACK-402: verifyLecturerSchedule(schedule_id, lecturer_id)
    public static function verifyLecturerSchedule(int $scheduleId, int $lecturerId): bool
    {
        return self::where('schedule_id', $scheduleId)
            ->where('lecturer_id', $lecturerId)
            ->exists();
    }

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
