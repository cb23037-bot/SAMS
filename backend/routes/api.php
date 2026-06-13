<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\LecturerAttendanceController;
use App\Http\Controllers\StudentAttendanceController;
use App\Http\Controllers\AttendanceReportController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| SAMS — Manage Student Attendance API Routes
| All routes under /api/
|--------------------------------------------------------------------------
*/

// ── Public routes ──────────────────────────────────────────────────────────
Route::post('/login',  [AuthController::class, 'login']);

// ── Authenticated routes (Sanctum token required) ─────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me',      [AuthController::class, 'me']);

    // ── Lecturer routes (role: lecturer) ───────────────────────────────────
    Route::middleware('role:lecturer')->prefix('lecturer')->group(function () {

        // SAMS-PACK-407: Class schedules
        Route::get('/schedules',                     [LecturerAttendanceController::class, 'getAssignedSchedules']);
        Route::get('/schedules/today',               [LecturerAttendanceController::class, 'getTodaySchedules']);
        // FIX: enrolled count endpoint for active session screen
        Route::get('/schedules/{id}/enrolled-count', [LecturerAttendanceController::class, 'getEnrolledCount']);

        // SAMS-PACK-408: Session management
        Route::post('/sessions/start',              [LecturerAttendanceController::class, 'startSession']);
        Route::post('/sessions/{id}/generate-code', [LecturerAttendanceController::class, 'generateCode']);
        Route::get('/sessions/{id}/live',           [LecturerAttendanceController::class, 'getLiveSubmissions']);
        Route::post('/sessions/{id}/close',         [LecturerAttendanceController::class, 'closeSession']);

        // SAMS-PACK-409: Records
        Route::get('/sessions/{id}/record', [LecturerAttendanceController::class, 'viewRecord']);

        // SAMS-PACK-410/416: Reports (FIX: /report/filter now properly used by Flutter)
        Route::get('/report/filter',   [AttendanceReportController::class, 'getReportFilter']);
        Route::get('/report',          [AttendanceReportController::class, 'generateReport']);
        // FIX: SAMS-REQ-414 — download report as CSV
        Route::get('/report/download', [AttendanceReportController::class, 'downloadReport']);
    });

    // ── Student routes (role: student) ─────────────────────────────────────
    Route::middleware('role:student')->prefix('student')->group(function () {

        // SAMS-PACK-413: Enrolled schedules
        Route::get('/schedules', [StudentAttendanceController::class, 'getEnrolledSchedules']);

        // SAMS-PACK-412/415: Active session check
        Route::get('/schedules/{scheduleId}/active-session', [StudentAttendanceController::class, 'getActiveSession']);

        // SAMS-PACK-415: Submit attendance
        Route::post('/attendance/submit', [StudentAttendanceController::class, 'submitAttendance']);
    });
});
