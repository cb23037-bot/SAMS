<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SubjectRegistration extends Model
{
    // Allow mass assignment for these fields
    protected $fillable = [
        'user_id', 'subject_id', 'lecture_section', 'lecture_instructor', 
        'lecture_schedule', 'lab_section', 'lab_instructor', 'lab_schedule', 'status'
    ];

    // Define the relationship to the Subject model
    public function subject()
    {
        return $this->belongsTo(Subject::class);
    }

    // Define the relationship to the User model
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}