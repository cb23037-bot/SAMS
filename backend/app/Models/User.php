<?php

namespace App\Models;

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

/**
 * User Model -- SAMS-PACK-401
 *
 * Manages lecturer and student user information used for authentication,
 * role identification, and attendance access control.
 *
 * Attributes:
 *   - id (user_id) : int       -- Primary key, unique user identifier.
 *   - name         : String    -- Full name of the user.
 *   - email        : String    -- Email address used for login.
 *   - password     : String    -- Hashed password for authentication.
 *   - role         : String    -- User role: 'lecturer', 'student', etc.
 *   - status       : String    -- Account status: 'active' or 'inactive'.
 *   - created_at   : Timestamp -- Record creation timestamp.
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
    // SDD Methods -- SAMS-PACK-401
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
     */
    public function logout(): void
    {
        $this->tokens()->delete();
    }

    /**
     * getUserRole()
     *
     * Retrieves the role assigned to this user.
     */
    public function getUserRole(): string
    {
        return $this->role;
    }

    /**
     * updateStatus()
     *
     * Updates the account status of this user to the given value.
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
