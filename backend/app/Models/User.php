<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Support\Facades\Hash;

/**
 * User — Entity Model
 * Requirement ID : SAMS-PACK-401
 * Responsibility : Represents a system user — either a lecturer or student.
 *                  Manages authentication credentials, role assignment, and
 *                  relationships to schedules, enrollments, and submissions.
 *
 * Attributes:
 *   id            int
 *   name          String
 *   email         String
 *   password      String  (hashed)
 *   role          String  ('lecturer' | 'student')
 *   student_id    String|null
 *   course        String|null
 *   phone_number  String|null
 *   status        String  ('active' | 'inactive')
 *   created_at    Timestamp
 *   updated_at    Timestamp
 *
 * Relationships:
 *   lecturerSchedules  hasMany ClassSchedule (lecturer_id)
 *   enrollments        hasMany ClassEnrollment (student_id)
 *   attendanceSubmissions hasMany AttendanceSubmission (student_id)
 */
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

    /**
     * attemptLogin(email, password) — User|null
     * SAMS-PACK-401
     *
     * Authenticates a user by email and password.
     * Returns null if the user does not exist, is inactive, or password is wrong.
     *
     * Algorithm:
     *   FIND user WHERE email = email
     *   IF user not found THEN RETURN null
     *   IF user.status != 'active' THEN RETURN null
     *   IF Hash.check(password, user.password) fails THEN RETURN null
     *   RETURN user
     */
    public static function attemptLogin(string $email, string $password): ?self
    {
        $user = self::where('email', $email)->first();
        if (!$user) return null;
        if ($user->status !== 'active') return null;
        if (!Hash::check($password, $user->password)) return null;
        return $user;
    }

    /**
     * getUserRole() — String
     * SAMS-PACK-401
     *
     * Returns the role of the user ('lecturer' or 'student').
     *
     * Algorithm:
     *   RETURN user.role
     */
    public function getUserRole(): string
    {
        return $this->role;
    }

    /**
     * updateStatus(status) — Boolean
     * SAMS-PACK-401
     *
     * Updates the user account status (e.g. activate or deactivate).
     *
     * Algorithm:
     *   SET user.status = status
     *   SAVE user
     *   RETURN true if saved successfully ELSE false
     */
    public function updateStatus(string $status): bool
    {
        $this->status = $status;
        return $this->save();
    }

    // ── Relationships ─────────────────────────────────────────────────────────

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
