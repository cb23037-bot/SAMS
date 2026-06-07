<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\CreditClaimController;
use App\Http\Controllers\Api\ActivityRegistrationController;
use App\Http\Controllers\Api\ActivitySlotController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProfileController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AcademicSessionController;
use App\Http\Controllers\Api\SubjectController;


Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::put('/profile', [ProfileController::class, 'update']);

    // Curriculum Activities (GET open to all roles; write actions adab only)
    Route::get('/activities', [ActivityController::class, 'index']);
    Route::post('/activities', [ActivityController::class, 'store']);
    Route::put('/activities/{activity}', [ActivityController::class, 'update']);
    Route::delete('/activities/{activity}', [ActivityController::class, 'destroy']);

    // Activity Slots (adab only)
    Route::post('/activities/{activity}/slots', [ActivitySlotController::class, 'store']);
    Route::delete('/activities/{activity}/slots/{slot}', [ActivitySlotController::class, 'destroy']);

    // Student access state (readable by any authenticated user)
    Route::get('/student/access', [AccessController::class, 'studentCheck']);

    // Student activity registrations
    Route::get('/student/registrations', [ActivityRegistrationController::class, 'index']);
    Route::post('/student/registrations', [ActivityRegistrationController::class, 'store']);
    Route::delete('/student/registrations/{registration}', [ActivityRegistrationController::class, 'destroy']);
    Route::post('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'claim']);
    Route::delete('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'cancelClaim']);

    // Attendance submission (students only — generates receipt)
    Route::post('/student/attendances', [AttendanceController::class, 'store']);

    // Adab: access control
    Route::get('/adab/access', [AccessController::class, 'show']);
    Route::put('/adab/access', [AccessController::class, 'update']);

    // Adab: credit claim management
    Route::get('/adab/notifications', [CreditClaimController::class, 'notifications']);
    Route::get('/adab/claims', [CreditClaimController::class, 'index']);
    Route::get('/adab/claims/{activityId}', [CreditClaimController::class, 'activityClaims']);
    Route::get('/adab/claims/{registration}/proof', [CreditClaimController::class, 'downloadProof']);
    Route::put('/adab/claims/{registration}/approve', [CreditClaimController::class, 'approve']);
    Route::put('/adab/claims/{registration}/reject', [CreditClaimController::class, 'reject']);


    //Open Registration
    Route::get('/academic-sessions', [AcademicSessionController::class, 'index']);
    Route::put('/academic-sessions/{id}/registration', [AcademicSessionController::class, 'updateRegistration']);
    Route::get('/subjects', [SubjectController::class, 'index']);
    Route::post('/subjects', [SubjectController::class, 'store']);

    // Student subject registration
    Route::get('/student/subject-registrations', [SubjectController::class, 'getRegisteredSubjects']);
    Route::post('/student/subject-registrations', [SubjectController::class, 'registerSubject']);
    Route::delete('/student/subject-registrations/{subject_id}', [SubjectController::class, 'unregisterSubject']);
    Route::post('/student/subject-registrations/submit', [SubjectController::class, 'submitRegistration']);

    // Lecturer approval workflow
    Route::get('/lecturer/subject-registrations/pending', [SubjectController::class, 'getPendingApprovals']);
    Route::put('/lecturer/subject-registrations/{registration}/approve', [SubjectController::class, 'approveSubjectRegistration']);
    Route::get('/lecturer/student/{studentId}/pending-subjects', [SubjectController::class, 'getStudentPendingSubjects']);
});
