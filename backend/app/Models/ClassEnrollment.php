<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ClassEnrollment extends Model
{
    protected $fillable = ['student_id', 'class_id', 'semester', 'status'];

    // Count enrolled students for a class_id
    public static function countEnrolledStudents(int $classId): int
    {
        return self::where('class_id', $classId)->where('status', 'enrolled')->count();
    }

    // Get enrolled class_ids for a student
    public static function getEnrolledClassIds(int $studentId): array
    {
        return self::where('student_id', $studentId)
            ->where('status', 'enrolled')
            ->pluck('class_id')
            ->toArray();
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }
}
