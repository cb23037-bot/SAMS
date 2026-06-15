<?php

use App\Http\Controllers\Api\AccessController;
use App\Http\Controllers\Api\ActivityController;
use App\Http\Controllers\Api\ActivityRegistrationController;
use App\Http\Controllers\Api\ActivitySlotController;
use App\Http\Controllers\Api\AttendanceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CreditClaimController;
use App\Http\Controllers\Api\FeeController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\ReceiptController;
use App\Http\Controllers\Api\TreasuryController;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::put('/profile', [ProfileController::class, 'update']);

    // ── Curriculum Activities ────────────────────────────────────────────────
    Route::get('/activities', [ActivityController::class, 'index']);
    Route::post('/activities', [ActivityController::class, 'store']);
    Route::put('/activities/{activity}', [ActivityController::class, 'update']);
    Route::delete('/activities/{activity}', [ActivityController::class, 'destroy']);

    Route::post('/activities/{activity}/slots', [ActivitySlotController::class, 'store']);
    Route::delete('/activities/{activity}/slots/{slot}', [ActivitySlotController::class, 'destroy']);

    // ── Student: access state + restriction status ───────────────────────────
    Route::get('/student/access', [AccessController::class, 'studentCheck']);
    Route::get('/student/restriction-status', [FeeController::class, 'restrictionStatus']);

    // ── Student: registrations (restricted students blocked from booking) ────
    Route::get('/student/registrations', [ActivityRegistrationController::class, 'index']);
    Route::post('/student/registrations', [ActivityRegistrationController::class, 'store'])
        ->middleware('academic.access');
    Route::delete('/student/registrations/{registration}', [ActivityRegistrationController::class, 'destroy']);
    Route::post('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'claim']);
    Route::delete('/student/registrations/{registration}/claim', [ActivityRegistrationController::class, 'cancelClaim']);

    // ── Attendance (blocked when financially restricted) ─────────────────────
    Route::post('/student/attendances', [AttendanceController::class, 'store'])
        ->middleware('academic.access');

    // ── Fees: student endpoints ──────────────────────────────────────────────
    Route::get('/fees', [FeeController::class, 'index']);
    Route::get('/fees/{fee}', [FeeController::class, 'show']);
    Route::post('/fees/{fee}/pay', [FeeController::class, 'pay']);
    Route::get('/payments', [FeeController::class, 'history']);
    Route::get('/payments/{payment}/receipt', [FeeController::class, 'receipt']);
    Route::get('/student/sponsors', [FeeController::class, 'sponsors']);
    Route::get('/student/ledger', [FeeController::class, 'ledger']);

    // ── Notifications ────────────────────────────────────────────────────────
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::put('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::put('/notifications/read-all', [NotificationController::class, 'markAllRead']);

    // ── Receipt PDF download ─────────────────────────────────────────────────
    Route::get('/receipts/{payment}/download', [ReceiptController::class, 'download']);

    // ── Pusat Adab ───────────────────────────────────────────────────────────
    Route::get('/adab/access', [AccessController::class, 'show']);
    Route::put('/adab/access', [AccessController::class, 'update']);
    Route::get('/adab/notifications', [CreditClaimController::class, 'notifications']);
    Route::get('/adab/claims', [CreditClaimController::class, 'index']);
    Route::get('/adab/claims/{activityId}', [CreditClaimController::class, 'activityClaims']);
    Route::get('/adab/claims/{registration}/proof', [CreditClaimController::class, 'downloadProof']);
    Route::put('/adab/claims/{registration}/approve', [CreditClaimController::class, 'approve']);
    Route::put('/adab/claims/{registration}/reject', [CreditClaimController::class, 'reject']);

    // ── Treasury ─────────────────────────────────────────────────────────────
    Route::get('/treasury/dashboard', [TreasuryController::class, 'dashboard']);
    Route::get('/treasury/stats', [TreasuryController::class, 'stats']);
    Route::get('/treasury/fees', [TreasuryController::class, 'feeRecords']);
    Route::get('/treasury/fees/{fee}', [TreasuryController::class, 'feeDetail']);
    Route::put('/treasury/fees/{fee}', [TreasuryController::class, 'updateRecord']);
    Route::get('/treasury/unpaid', [TreasuryController::class, 'unpaid']);
    Route::post('/treasury/restrict/{userId}', [TreasuryController::class, 'restrict']);
    Route::delete('/treasury/restrict/{userId}', [TreasuryController::class, 'lift']);
    Route::get('/treasury/settings', [TreasuryController::class, 'getSettings']);
    Route::put('/treasury/settings', [TreasuryController::class, 'updateSettings']);
});
