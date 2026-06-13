<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\CreditClaimController;
use App\Http\Controllers\Api\ActivityRegistrationController;
use App\Http\Controllers\Api\ActivitySlotController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\FeeController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\TreasuryController;
use Illuminate\Support\Facades\Route;

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

    // Student fees and payments
    Route::get('/fees', [FeeController::class, 'index']);
    Route::get('/fees/{fee}', [FeeController::class, 'show']);
    Route::post('/fees/{fee}/pay', [FeeController::class, 'pay']);
    Route::get('/payments', [FeeController::class, 'history']);

    // Treasury fee management
    Route::get('/treasury/dashboard', [TreasuryController::class, 'dashboard']);
    Route::get('/treasury/fees', [TreasuryController::class, 'feeRecords']);
    Route::get('/treasury/fees/{fee}', [TreasuryController::class, 'feeDetail']);
    Route::get('/treasury/unpaid', [TreasuryController::class, 'unpaid']);
});
