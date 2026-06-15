<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Restriction extends Model
{
    protected $fillable = [
        'student_id', 'restriction_type', 'status',
        'applied_date', 'lifted_date', 'lifted_by',
    ];

    protected $casts = [
        'applied_date' => 'date',
        'lifted_date'  => 'date',
    ];

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public static function isRestricted(int $userId): bool
    {
        $student = Student::where('user_id', $userId)->first();
        if (!$student) return false;

        return self::where('student_id', $student->id)
            ->where('status', 'Active')
            ->exists();
    }
}
