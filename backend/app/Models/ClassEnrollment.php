<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ClassEnrollment extends Model
{
    protected $table = 'class_enrollments';

    protected $fillable = [
        'student_id',
        'class_id',
        'semester',
        'status',
    ];

    /**
     * The enrolled student.
     */
    public function student(): BelongsTo
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    /**
     * The class schedule(s) associated with this enrollment's class_id.
     */
    public function schedules()
    {
        return ClassSchedule::where('class_id', $this->class_id)->get();
    }

    /**
     * Get the list of class IDs a student is currently enrolled in.
     */
    public static function getEnrolledClassIds(int $studentId): array
    {
        return static::where('student_id', $studentId)
            ->where('status', 'enrolled')
            ->pluck('class_id')
            ->toArray();
    }
}
