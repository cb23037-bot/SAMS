<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Support\Facades\Hash; 

// SAMS-PACK-401
class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'role',
        'student_id', 'course', 'phone_number', 'status',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'password' => 'hashed',
    ];

    // SAMS-PACK-401: login() — authenticate credentials
    public static function attemptLogin(string $email, string $password): ?self
    {
        $user = self::where('email', $email)->first();
        if (!$user) return null;
        if ($user->status !== 'active') return null;
        if (!Hash::check($password, $user->password)) return null;
        return $user;
    }

    // SAMS-PACK-401: getUserRole()
    public function getUserRole(): string
    {
        return $this->role;
    }

    // SAMS-PACK-401: updateStatus()
    public function updateStatus(string $status): bool
    {
        $this->status = $status;
        return $this->save();
    }

    // Relationships
    public function lecturerSchedules()
    {
        return $this->hasMany(ClassSchedule::class, 'lecturer_id');
    }

    public function enrollments()
    {
        return $this->hasMany(ClassEnrollment::class, 'student_id');
    }

    public function attendanceSubmissions()
    {
        return $this->hasMany(AttendanceSubmission::class, 'student_id');
    }
}
