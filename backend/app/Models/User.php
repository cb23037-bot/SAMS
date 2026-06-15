<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Restriction;
use App\Models\SubjectRegistration;
use App\Models\ClassSchedule;
use App\Models\ClassEnrollment;
use App\Models\AttendanceSession;
use App\Models\ClassAttendanceSubmission;


class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'role',
        'student_id',
        'course',
        'phone_number',
        'current_semester',
        'personal_advisor',
        'address',
        'password',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'password' => 'hashed',
    ];

    /**
     * Get the subject registrations for this user.
     */
    public function subjectRegistrations(): HasMany
    {
        return $this->hasMany(SubjectRegistration::class);
    }

    /**
     * Get all students who list this lecturer as their personal advisor.
     */
    public function advisees(): HasMany
    {
        return $this->hasMany(User::class, 'personal_advisor', 'name');
    }

    public function restrictions(): HasMany
    {
        return $this->hasMany(Restriction::class);
    }

    /**
     * Get the class schedules assigned to this lecturer.
     */
    public function lecturerClassSchedules(): HasMany
    {
        return $this->hasMany(ClassSchedule::class, 'lecturer_id');
    }

    /**
     * Get the class enrollments for this student.
     */
    public function classEnrollments(): HasMany
    {
        return $this->hasMany(ClassEnrollment::class);
    }

    /**
     * Get the attendance sessions started by this lecturer.
     */
    public function attendanceSessions(): HasMany
    {
        return $this->hasMany(AttendanceSession::class, 'lecturer_id');
    }

    /**
     * Get the class attendance submissions made by this student.
     */
    public function classAttendanceSubmissions(): HasMany
    {
        return $this->hasMany(ClassAttendanceSubmission::class);
    }
}
