<?php

namespace App\Http\Controllers;

use App\Models\AttendanceSession;
use App\Models\AttendanceSubmission;
use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * LecturerAttendanceController — Controller
 * Requirement ID : SAMS-PACK-414
 * Responsibility : Handles lecturer attendance operations including viewing schedules,
 *                  starting attendance sessions, generating codes, monitoring live
 *                  submissions, closing sessions, and viewing attendance records.
 *
 * Attributes:
 *   scheduleModel    ClassSchedule
 *   sessionModel     AttendanceSession
 *   submissionModel  AttendanceSubmission
 *   boundaryModel    CampusBoundary
 */
class LecturerAttendanceController extends Controller
{
    /**
     * getAssignedSchedules(lecturer_id) — List<ClassSchedule>
     * SAMS-PACK-414
     * GET /api/lecturer/schedules
     *
     * Retrieves all class schedules assigned to the authenticated lecturer.
     * Each schedule includes its active session data (if any) so the frontend
     * can show the "View Code" button without an extra request.
     *
     * Algorithm:
     *   GET lecturer_id from session
     *   CALL ClassSchedule.getLecturerSchedules(lecturer_id)
     *   RETURN schedule list
     */
    public function getAssignedSchedules(Request $request): JsonResponse
    {
        $lecturerId = $request->user()->id;
        $schedules  = ClassSchedule::getLecturerSchedules($lecturerId);
        return response()->json(['schedules' => $schedules]);
    }

    /**
     * getTodaySchedules(lecturer_id) — List<ClassSchedule>
     * SAMS-PACK-414
     * GET /api/lecturer/schedules/today
     *
     * Retrieves the lecturer's class schedules for today only.
     * Used by the lecturer dashboard to display today's session cards.
     *
     * Algorithm:
     *   GET lecturer_id from session
     *   CALL ClassSchedule.getTodaySchedule(lecturer_id)
     *   RETURN schedule list
     */
    public function getTodaySchedules(Request $request): JsonResponse
    {
        $lecturerId = $request->user()->id;
        $schedules  = ClassSchedule::getTodaySchedule($lecturerId);
        return response()->json(['schedules' => $schedules]);
    }

    /**
     * getEnrolledCount(schedule_id) — int
     * SAMS-PACK-414
     * GET /api/lecturer/schedules/{id}/enrolled-count
     *
     * Returns the total number of enrolled students for a class.
     * Used by the active session screen to display the enrolled/present ratio.
     */
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

    /**
     * startSession(schedule_id, lecturer_id) — AttendanceSession
     * SAMS-PACK-414
     * POST /api/lecturer/sessions/start
     *
     * Creates a new active attendance session for the given schedule.
     * Validates lecturer ownership and checks for an already-active session (SAMS-REQ-425).
     *
     * Algorithm:
     *   GET lecturer_id and schedule_id
     *   CALL ClassSchedule.verifyLecturerSchedule(lecturer_id, schedule_id)
     *   IF lecturer is not assigned THEN RETURN error "Unauthorized access to this class"
     *   CALL CampusBoundary.getActiveBoundary()
     *   CALL AttendanceSession.createSession(schedule_id, lecturer_id, campus_boundary_id)
     *   IF session created THEN RETURN attendance session
     *   ELSE RETURN error "An attendance session is already active for this class"
     */
    public function startSession(Request $request): JsonResponse
    {
        $request->validate(['schedule_id' => 'required|integer']);

        $lecturerId = $request->user()->id;
        $scheduleId = $request->schedule_id;

        if (!ClassSchedule::verifyLecturerSchedule($scheduleId, $lecturerId)) {
            return response()->json(['message' => 'Unauthorized access to this class.'], 403);
        }

        $boundary = CampusBoundary::getActiveBoundary();
        if (!$boundary) {
            return response()->json(['message' => 'No active campus boundary configured.'], 500);
        }

        $result = AttendanceSession::createSession($scheduleId, $lecturerId, $boundary->campus_boundary_id);

        if (is_string($result)) {
            // SAMS-REQ-425: active session already exists
            return response()->json(['message' => $result], 409);
        }

        return response()->json(['session' => $result], 201);
    }

    /**
     * generateCode(attendance_session_id) — String
     * SAMS-PACK-414
     * POST /api/lecturer/sessions/{id}/generate-code
     *
     * Generates a new unique attendance code for an active session.
     * Verifies that the requesting lecturer owns the session before generating.
     *
     * Algorithm:
     *   GET attendance_session_id
     *   CALL AttendanceSession.generateCode(attendance_session_id)
     *   IF code generated THEN RETURN code
     *   ELSE RETURN error "Unable to generate attendance code"
     */
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

    /**
     * getLiveSubmissions(attendance_session_id) — List<AttendanceSubmission>
     * SAMS-PACK-414
     * GET /api/lecturer/sessions/{id}/live
     *
     * Retrieves real-time attendance submissions for an active session.
     * Polled every 5 seconds by the active session screen.
     *
     * Algorithm:
     *   GET attendance_session_id
     *   CALL AttendanceSubmission.getSubmissionsBySession(attendance_session_id)
     *   RETURN submission list
     */
    public function getLiveSubmissions(Request $request, int $sessionId): JsonResponse
    {
        $session = AttendanceSession::find($sessionId);
        if (!$session || $session->lecturer_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized or not found.'], 403);
        }

        $submissions = AttendanceSubmission::getSubmissionsBySession($sessionId);
        return response()->json(['submissions' => $submissions]);
    }

    /**
     * closeSession(attendance_session_id) — Boolean
     * SAMS-PACK-414
     * POST /api/lecturer/sessions/{id}/close
     *
     * Closes an active attendance session. Students can no longer submit after this.
     * Verifies lecturer ownership before closing.
     *
     * Algorithm:
     *   GET lecturer_id and attendance_session_id
     *   FIND attendance session by attendance_session_id
     *   IF session.lecturer_id != lecturer_id THEN RETURN error "Unauthorized access"
     *   CALL AttendanceSession.closeSession(attendance_session_id)
     *   RETURN result
     */
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

    /**
     * viewRecord(attendance_session_id) — List<AttendanceSubmission>
     * SAMS-PACK-414
     * GET /api/lecturer/sessions/{id}/record
     *
     * Retrieves the full attendance record for a completed or active session,
     * including all student submissions with student details.
     *
     * Algorithm:
     *   GET attendance_session_id
     *   CALL AttendanceSubmission.getSubmissionsBySession(attendance_session_id)
     *   RETURN attendance records
     */
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
