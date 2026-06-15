<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\CreditClaimController;
use App\Http\Controllers\Api\ActivityRegistrationController;
use App\Http\Controllers\Api\ActivitySlotController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AttendanceReportController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\LecturerAttendanceController;
use App\Http\Controllers\Api\StudentAttendanceController;
use App\Http\Controllers\Api\FeeController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\TreasuryController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AcademicSessionController;
use App\Http\Controllers\Api\SubjectController;
use App\Http\Controllers\Api\SubjectRegistrationController;

Route::post('/login', [AuthController::class, 'login']);
Route::post('/forgot-password', [AuthController::class, 'forgotPassword']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::put('/profile', [ProfileController::class, 'update']);

    // --- Activities & Slots ---
    Route::get('/activities', [ActivityController::class, 'index']);
    Route::post('/activities', [ActivityController::class, 'store']);
    Route::put('/activities/{activity}', [ActivityController::class, 'update']);
    Route::delete('/activities/{activity}', [ActivityController::class, 'destroy']);
    
    Route::post('/activities/{activity}/slots', [ActivitySlotController::class, 'store']);
    Route::put('/activities/{activity}/slots/{slot}', [ActivitySlotController::class, 'update']);
    Route::delete('/activities/{activity}/slots/{slot}', [ActivitySlotController::class, 'destroy']);

    // --- Student Access & Registrations ---
    Route::get('/student/access', [AccessController::class, 'studentCheck']);
    Route::get('/student/restriction-status', [FeeController::class, 'restrictionStatus']);
    Route::get('/student/registrations', [ActivityRegistrationController::class, 'index']);
    Route::post('/student/registrations', [ActivityRegistrationController::class, 'store'])
        ->middleware('academic.access');
    Route::delete('/student/registrations/{registration}', [ActivityRegistrationController::class, 'destroy']);
    Route::post('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'claim']);
    Route::delete('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'cancelClaim']);
    Route::post('/student/attendances', [AttendanceController::class, 'store'])
        ->middleware('academic.access');

    // --- Adab (PA/Lecturer) Management ---
    Route::prefix('adab')->group(function () {
        Route::get('/access', [AccessController::class, 'show']);
        Route::put('/access', [AccessController::class, 'update']);
        Route::get('/notifications', [CreditClaimController::class, 'notifications']);
        Route::get('/claims', [CreditClaimController::class, 'index']);
        Route::get('/claims/{activityId}', [CreditClaimController::class, 'activityClaims']);
        Route::get('/claims/{registration}/proof', [CreditClaimController::class, 'downloadProof']);
        Route::put('/claims/{registration}/approve', [CreditClaimController::class, 'approve']);
        Route::put('/claims/{registration}/reject', [CreditClaimController::class, 'reject']);
    });

    // --- Academic Sessions ---
    Route::prefix('academic-sessions')->group(function () {
        Route::get('/active', [AcademicSessionController::class, 'getActiveSession']);
        Route::get('/', [AcademicSessionController::class, 'index']);
        Route::post('/', [AcademicSessionController::class, 'store']);
        Route::post('/{id}/set-registration-status', [AcademicSessionController::class, 'setRegistrationStatus']);
        Route::put('/{id}/registration', [AcademicSessionController::class, 'updateRegistration']);
        Route::delete('/{id}', [AcademicSessionController::class, 'destroy']);
    });

    // --- Subjects Management ---
    Route::get('/subjects', [SubjectController::class, 'index']);
    Route::post('/subjects', [SubjectController::class, 'store']);
    Route::delete('/subjects/{id}', [SubjectController::class, 'destroy']);
    Route::get('/subjects/{id}/sections', [SubjectController::class, 'getSections']);

    // --- Subject Registration Workflow ---
    Route::prefix('student')->group(function () {
        Route::get('/subject-registrations', [SubjectRegistrationController::class, 'index']);
        Route::post('/subject-registrations', [SubjectRegistrationController::class, 'store']);
        Route::delete('/subject-registrations/{id}', [SubjectRegistrationController::class, 'destroy']);
        Route::post('/subject-registrations/submit', [SubjectRegistrationController::class, 'submitRegistration']);

        // --- Class Attendance (Student) ---
        Route::get('/attendance/schedules', [StudentAttendanceController::class, 'getSchedules']);
        Route::get('/attendance/schedules/{scheduleId}/active-session', [StudentAttendanceController::class, 'getActiveSession']);
        Route::post('/attendance/submit', [StudentAttendanceController::class, 'submitAttendance']);
    });

    Route::prefix('lecturer')->middleware('auth:sanctum')->group(function () {
        // List all pending registrations for the lecturer/PA to see
        Route::get('/subject-registrations/pending', [SubjectRegistrationController::class, 'getPendingApprovals']);
        
        // Update the status of a specific registration (Approve or Reject)
        Route::patch('/subject-registrations/{registration}/status', [SubjectRegistrationController::class, 'updateStatus']);
        
        // View a specific student's pending subjects
        Route::get('/student/{studentId}/pending-subjects', [SubjectRegistrationController::class, 'getStudentPendingSubjects']);

        // Approve all pending registrations for a specific student
        Route::post('/student/{studentId}/approve-all', [SubjectRegistrationController::class, 'approveAll']);

        // --- Class Attendance (Lecturer) ---
        Route::get('/attendance/schedules', [LecturerAttendanceController::class, 'getSchedules']);
        Route::get('/attendance/schedules/today', [LecturerAttendanceController::class, 'getTodaySchedules']);
        Route::get('/attendance/schedules/{scheduleId}/enrolled-count', [LecturerAttendanceController::class, 'getEnrolledCount']);
        Route::post('/attendance/sessions/start', [LecturerAttendanceController::class, 'startSession']);
        Route::post('/attendance/sessions/{sessionId}/generate-code', [LecturerAttendanceController::class, 'generateCode']);
        Route::get('/attendance/sessions/{sessionId}/live', [LecturerAttendanceController::class, 'getLiveSubmissions']);
        Route::post('/attendance/sessions/{sessionId}/close', [LecturerAttendanceController::class, 'closeSession']);
        Route::get('/attendance/sessions/{sessionId}/record', [LecturerAttendanceController::class, 'viewRecord']);

        // --- Attendance Reports (Lecturer) ---
        Route::get('/attendance/report/filters', [AttendanceReportController::class, 'getReportFilters']);
        Route::get('/attendance/report', [AttendanceReportController::class, 'generateReport']);
        Route::get('/attendance/report/download', [AttendanceReportController::class, 'downloadReport']);
    });

    // ── Module 3: Fees (student) ─────────────────────────────────────────────
    Route::get('/fees', [FeeController::class, 'index']);
    Route::get('/fees/{fee}', [FeeController::class, 'show']);
    Route::post('/fees/{fee}/pay', [FeeController::class, 'pay']);
    Route::get('/payments', [FeeController::class, 'history']);
    Route::get('/payments/{payment}/receipt', [FeeController::class, 'receipt']);
    Route::get('/student/sponsors', [FeeController::class, 'sponsors']);
    Route::get('/student/ledger', [FeeController::class, 'ledger']);

    // ── Module 3: Notifications ──────────────────────────────────────────────
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::put('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::put('/notifications/read-all', [NotificationController::class, 'markAllRead']);

    // ── Module 3: Receipt PDF download ───────────────────────────────────────
    Route::get('/receipts/{payment}/download', [ReceiptController::class, 'download']);

    // ── Module 3: Treasury ───────────────────────────────────────────────────
    Route::get('/treasury/dashboard', [TreasuryController::class, 'dashboard']);
    Route::get('/treasury/stats', [TreasuryController::class, 'stats']);
    Route::get('/treasury/fees', [TreasuryController::class, 'feeRecords']);
    Route::get('/treasury/fees/{fee}', [TreasuryController::class, 'feeDetail']);
    Route::put('/treasury/fees/{fee}', [TreasuryController::class, 'updateRecord']);
    Route::get('/treasury/unpaid', [TreasuryController::class, 'unpaid']);
    Route::post('/treasury/restrict/{userId}', [TreasuryController::class, 'restrict']);
    Route::delete('/treasury/restrict/{userId}', [TreasuryController::class, 'lift']);
});
