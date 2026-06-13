<?php

namespace App\Http\Controllers;

use App\Models\AttendanceSession;
use App\Models\AttendanceSubmission;
use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

// SAMS-PACK-414 — LecturerAttendanceController
class LecturerAttendanceController extends Controller
{
    // SAMS-PACK-414: getAssignedSchedules(lecturer_id)
    // GET /api/lecturer/schedules
    public function getAssignedSchedules(Request $request): JsonResponse
    {
        $lecturerId = $request->user()->id;
        $schedules  = ClassSchedule::getLecturerSchedules($lecturerId);
        return response()->json(['schedules' => $schedules]);
    }

    // GET /api/lecturer/schedules/today
    public function getTodaySchedules(Request $request): JsonResponse
    {
        $lecturerId = $request->user()->id;
        $schedules  = ClassSchedule::getTodaySchedule($lecturerId);
        return response()->json(['schedules' => $schedules]);
    }

    // FIX: GET /api/lecturer/schedules/{id}/enrolled-count
    // Returns total enrolled students for a class — used by active session screen
    public function getEnrolledCount(Request $request, int $scheduleId): JsonResponse
    {
        $schedule = ClassSchedule::find($scheduleId);

        if (!$schedule) {
            return response()->json(['message' => 'Schedule not found.'], 404);
        }
        if (!ClassSchedule::verifyLecturerSchedule($scheduleId, $request->user()->id)) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $count = ClassEnrollment::countEnrolledStudents($schedule->class_id);
        return response()->json(['enrolled_count' => $count]);
    }

    // SAMS-PACK-414: startSession(schedule_id, lecturer_id)
    // POST /api/lecturer/sessions/start
    public function startSession(Request $request): JsonResponse
    {
        $request->validate(['schedule_id' => 'required|integer']);

        $lecturerId = $request->user()->id;
        $scheduleId = $request->schedule_id;

        // SAMS-REQ-425: Detect existing active session
        // verifyLecturerSchedule — SAMS-PACK-402
        if (!ClassSchedule::verifyLecturerSchedule($scheduleId, $lecturerId)) {
            return response()->json(['message' => 'Unauthorized access to this class.'], 403);
        }

        $boundary = CampusBoundary::getActiveBoundary();
        if (!$boundary) {
            return response()->json(['message' => 'No active campus boundary configured.'], 500);
        }

        $result = AttendanceSession::createSession($scheduleId, $lecturerId, $boundary->campus_boundary_id);

        if (is_string($result)) {
            // SAMS-REQ-425
            return response()->json(['message' => $result], 409);
        }

        return response()->json(['session' => $result], 201);
    }

    // SAMS-PACK-414: generateCode(attendance_session_id)
    // POST /api/lecturer/sessions/{id}/generate-code
    public function generateCode(Request $request, int $sessionId): JsonResponse
    {
        $session = AttendanceSession::find($sessionId);
        if (!$session) {
            return response()->json(['message' => 'Session not found.'], 404);
        }
        if ($session->lecturer_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $code = $session->generateCode();
        if (!$code) {
            return response()->json(['message' => 'Unable to generate code. Session is not active.'], 422);
        }

        return response()->json(['attendance_code' => $code]);
    }

    // SAMS-PACK-414: getLiveSubmissions(attendance_session_id)
    // GET /api/lecturer/sessions/{id}/live
    public function getLiveSubmissions(Request $request, int $sessionId): JsonResponse
    {
        $session = AttendanceSession::find($sessionId);
        if (!$session || $session->lecturer_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized or not found.'], 403);
        }

        $submissions = AttendanceSubmission::getSubmissionsBySession($sessionId);
        return response()->json(['submissions' => $submissions]);
    }

    // SAMS-PACK-414: closeSession(attendance_session_id)
    // POST /api/lecturer/sessions/{id}/close
    public function closeSession(Request $request, int $sessionId): JsonResponse
    {
        $session = AttendanceSession::find($sessionId);
        if (!$session) {
            return response()->json(['message' => 'Session not found.'], 404);
        }
        if ($session->lecturer_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized access.'], 403);
        }

        $closed = AttendanceSession::closeSession($sessionId);
        if (!$closed) {
            return response()->json(['message' => 'Unable to close session.'], 422);
        }

        return response()->json(['message' => 'Session closed successfully.']);
    }

    // SAMS-PACK-414: viewRecord(attendance_session_id)
    // GET /api/lecturer/sessions/{id}/record
    public function viewRecord(Request $request, int $sessionId): JsonResponse
    {
        $session = AttendanceSession::with('schedule')->find($sessionId);
        if (!$session || $session->lecturer_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized or not found.'], 403);
        }

        $submissions = AttendanceSubmission::getSubmissionsBySession($sessionId);
        return response()->json([
            'session'     => $session,
            'submissions' => $submissions,
        ]);
    }
}
