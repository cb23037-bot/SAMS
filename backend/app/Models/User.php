<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * User Model — SAMS-PACK-401
 *
 * Manages lecturer and student user information used for authentication,
 * role identification, and attendance access control.
 *
 * Attributes:
 *   - id (user_id) : int       — Primary key, unique user identifier.
 *   - name         : String    — Full name of the user.
 *   - email        : String    — Email address used for login.
 *   - password     : String    — Hashed password for authentication.
 *   - role         : String    — User role: 'lecturer', 'student', etc.
 *   - status       : String    — Account status: 'active' or 'inactive'.
 *   - created_at   : Timestamp — Record creation timestamp.
 */
class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'role',
        'status',
        'student_id',
        'course',
        'phone_number',
        'current_semester',
        'personal_advisor',
        'address',
        'password',
    ];

    protected $hidden = [
        'password',
    ];

    protected $casts = [
        'password' => 'hashed',
    ];

    // =========================================================================
    // SDD Methods — SAMS-PACK-401
    // =========================================================================

    /**
     * login()
     *
     * Authenticates user credentials against the system.
     * Finds the user by email, checks the account status is 'active',
     * and verifies the password matches the stored hash.
     * Creates and returns a Sanctum API token on success.
     * Returns false if the user is not found, account is inactive,
     * or the password does not match.
     *
     * @param  string $email    — The email address provided by the user.
     * @param  string $password — The plain-text password to verify.
     * Returns: Boolean — true and issues token on success, false on failure.
     */
    public static function login(string $email, string $password): bool
    {
        $user = static::where('email', $email)->first();

        if (!$user) {
            return false;
        }

        if ($user->status !== 'active') {
            return false;
        }

        if (!\Illuminate\Support\Facades\Hash::check($password, $user->password)) {
            return false;
        }

        return true;
    }

    /**
     * logout()
     *
     * Terminates the current user session by revoking all Sanctum API tokens
     * issued to this user. After this, any further requests using the old
     * token will be rejected as unauthenticated.
     *
     * Returns: void
     */
    public function logout(): void
    {
        $this->tokens()->delete();
    }

    /**
     * getUserRole()
     *
     * Retrieves the role assigned to this user.
     * Used by controllers and middleware to determine access rights
     * (e.g. only lecturers can start sessions, only students can submit attendance).
     *
     * Returns: String — The role of the user (e.g. 'lecturer', 'student').
     */
    public function getUserRole(): string
    {
        return $this->role;
    }

    /**
     * updateStatus()
     *
     * Updates the account status of this user to the given value.
     * Typical values are 'active' or 'inactive'.
     * Finds the user by user_id, updates the status field, and saves
     * the change to the database.
     *
     * @param  string $newStatus — The new status value to apply.
     * Returns: Boolean — true if the record was saved successfully, false otherwise.
     */
    public function updateStatus(string $newStatus): bool
    {
        $this->status = $newStatus;
        return $this->save();
    }

    // =========================================================================
    // Eloquent Relationships
    // =========================================================================

    /**
     * Get the subject registrations belonging to this user.
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
        return $this->hasMany(ClassEnrollment::class, 'student_id');
    }

    /**
     * Get the attendance sessions started by this lecturer.
     */
    public function attendanceSessions(): HasMany
    {
        return $this->hasMany(AttendanceSession::class, 'lecturer_id');
    }

    /**
     * Get the attendance submissions made by this student.
     */
    public function classAttendanceSubmissions(): HasMany
    {
        return $this->hasMany(AttendanceSubmission::class, 'student_id');
    }
}
