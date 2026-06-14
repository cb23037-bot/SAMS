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
 * StudentAttendanceController — Controller
 * Requirement ID : SAMS-PACK-415
 * Responsibility : Handles student attendance submission, attendance code validation,
 *                  GPS verification, enrollment checking, duplicate checking,
 *                  and attendance record saving.
 *
 * Attributes:
 *   enrollmentModel  ClassEnrollment
 *   scheduleModel    ClassSchedule
 *   sessionModel     AttendanceSession
 *   boundaryModel    CampusBoundary
 *   submissionModel  AttendanceSubmission
 */
class StudentAttendanceController extends Controller
{
    /**
     * getEnrolledSchedules(student_id) — List<ClassSchedule>
     * SAMS-PACK-415
     * GET /api/student/schedules
     *
     * Retrieves all class schedules for the student's enrolled classes.
     * Attaches active session and already_submitted flags per schedule so the
     * student class list screen can show correct submission state.
     *
     * Algorithm:
     *   GET student_id from session
     *   FIND class enrollments WHERE student_id = student_id AND status = "enrolled"
     *   FOR each enrollment → FIND schedules WHERE class_id = enrollment.class_id
     *   ATTACH active_session and already_submitted per schedule
     *   RETURN enrolledScheduleList
     */
    public function getEnrolledSchedules(Request $request): JsonResponse
    {
        $studentId = $request->user()->id;
        $classIds  = ClassEnrollment::getEnrolledClassIds($studentId);

        $schedules = ClassSchedule::whereIn('class_id', $classIds)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();

        // Attach active session and submission status per schedule
        $schedules = $schedules->map(function ($schedule) use ($studentId) {
            $activeSession = AttendanceSession::getActiveSession($schedule->schedule_id);
            $schedule->active_session    = $activeSession;
            $schedule->already_submitted = $activeSession
                ? AttendanceSubmission::checkDuplicateSubmission(
                    $activeSession->attendance_session_id, $studentId
                  )
                : false;
            return $schedule;
        });

        return response()->json(['schedules' => $schedules]);
    }

    /**
     * getActiveSession(student_id, schedule_id) — AttendanceSession
     * SAMS-PACK-415
     * GET /api/student/schedules/{scheduleId}/active-session
     *
     * Retrieves the active attendance session for a student's enrolled class.
     * Verifies that the student is enrolled before returning the session.
     *
     * Algorithm:
     *   GET student_id from session
     *   VERIFY student is enrolled in schedule's class
     *   CALL AttendanceSession.getActiveSession(schedule_id)
     *   IF session found THEN RETURN session ELSE RETURN null with message
     */
    public function getActiveSession(Request $request, int $scheduleId): JsonResponse
    {
        $studentId = $request->user()->id;
        $schedule  = ClassSchedule::find($scheduleId);

        if (!$schedule) {
            return response()->json(['message' => 'Schedule not found.'], 404);
        }

        // Verify enrollment before exposing session data
        $enrolled = ClassEnrollment::where('student_id', $studentId)
            ->where('class_id', $schedule->class_id)
            ->where('status', 'enrolled')
            ->exists();

        if (!$enrolled) {
            return response()->json(['message' => 'You are not enrolled in this class.'], 403);
        }

        $session = AttendanceSession::getActiveSession($scheduleId);
        if (!$session) {
            return response()->json(['message' => 'Attendance session has ended or is not active.', 'session' => null]);
        }

        $alreadySubmitted = AttendanceSubmission::checkDuplicateSubmission(
            $session->attendance_session_id, $studentId
        );

        return response()->json([
            'session'           => $session,
            'already_submitted' => $alreadySubmitted,
        ]);
    }

    /**
     * submitAttendance(student_id, attendance_code, gps_latitude, gps_longitude) — Boolean
     * SAMS-PACK-415
     * POST /api/student/attendance/submit
     *
     * Processes a student's attendance submission. Runs through a validation pipeline:
     * active session check → code verification → GPS verification → duplicate check → save.
     *
     * Algorithm:
     *   CALL verifyAttendanceCode(inputCode, session.attendance_code)
     *   IF invalid THEN RETURN error "Invalid attendance code"
     *   CALL verifyGPSLocation(lat, lng, campus_boundary_id)
     *   IF outside campus THEN RETURN error "You are outside the permitted campus area"
     *   CALL checkDuplicateSubmission(session_id, student_id)
     *   IF duplicate THEN RETURN error "Attendance has already been submitted"
     *   CALL saveAttendanceRecord(session_id, student_id, code, lat, lng)
     *   RETURN submission record
     */
    public function submitAttendance(Request $request): JsonResponse
    {
        $request->validate([
            'schedule_id'     => 'required|integer',
            'attendance_code' => 'required|string|size:6',
            'gps_latitude'    => 'required|numeric|between:-90,90',
            'gps_longitude'   => 'required|numeric|between:-180,180',
        ]);

        $studentId  = $request->user()->id;
        $scheduleId = $request->schedule_id;
        $inputCode  = strtoupper(trim($request->attendance_code));
        $lat        = (float) $request->gps_latitude;
        $lng        = (float) $request->gps_longitude;

        // Check that an active session exists for this schedule
        $session = AttendanceSession::getActiveSession($scheduleId);
        if (!$session) {
            return response()->json(['message' => 'Attendance session has ended or is not active.'], 422);
        }

        // SAMS-PACK-415: verifyAttendanceCode
        if (!$this->verifyAttendanceCode($inputCode, $session->attendance_code)) {
            return response()->json(['message' => 'Invalid attendance code. Please check with your lecturer.'], 422);
        }

        // SAMS-PACK-415: verifyGPSLocation
        if (!$this->verifyGPSLocation($lat, $lng, $session->campus_boundary_id)) {
            return response()->json(['message' => 'You are outside the permitted campus area. Please move closer and try again.'], 422);
        }

        // SAMS-PACK-415: checkDuplicateSubmission
        if ($this->checkDuplicateSubmission($session->attendance_session_id, $studentId)) {
            return response()->json(['message' => 'Attendance has already been submitted for this session.'], 409);
        }

        // SAMS-PACK-415: saveAttendanceRecord
        $submission = $this->saveAttendanceRecord(
            $session->attendance_session_id, $studentId, $inputCode, $lat, $lng
        );

        if (is_string($submission)) {
            return response()->json(['message' => $submission], 409);
        }

        return response()->json([
            'message'    => 'Attendance submitted successfully.',
            'submission' => $submission,
        ], 201);
    }

    /**
     * verifyAttendanceCode(attendance_code) — Boolean
     * SAMS-PACK-415
     *
     * Checks whether the student-entered code matches the session's current code.
     *
     * Algorithm:
     *   IF inputCode = sessionCode THEN RETURN true ELSE RETURN false
     */
    private function verifyAttendanceCode(string $inputCode, string $sessionCode): bool
    {
        return $inputCode === $sessionCode;
    }

    /**
     * verifyGPSLocation(gps_latitude, gps_longitude) — Boolean
     * SAMS-PACK-415
     *
     * Checks whether the student's GPS coordinates are within the campus boundary.
     * Delegates to CampusBoundary.verifyLocation() which uses the Haversine formula.
     *
     * Algorithm:
     *   CALL CampusBoundary.verifyLocation(lat, lng, campus_boundary_id)
     *   IF distance <= allowed_radius_meter THEN RETURN true ELSE RETURN false
     */
    private function verifyGPSLocation(float $lat, float $lng, int $boundaryId): bool
    {
        return CampusBoundary::verifyLocation($lat, $lng, $boundaryId);
    }

    /**
     * checkDuplicateSubmission(attendance_session_id, student_id) — Boolean
     * SAMS-PACK-415
     *
     * Checks whether the student has already submitted for this session.
     *
     * Algorithm:
     *   FIND submission WHERE attendance_session_id AND student_id match
     *   IF found THEN RETURN true ELSE RETURN false
     */
    private function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return AttendanceSubmission::checkDuplicateSubmission($sessionId, $studentId);
    }

    /**
     * saveAttendanceRecord(attendance_session_id, student_id, submitted_code, gps_latitude, gps_longitude) — Boolean
     * SAMS-PACK-415
     *
     * Saves the validated attendance submission record to the database.
     *
     * Algorithm:
     *   CREATE new attendance submission with attendance_status = "present"
     *   RETURN submission record
     */
    private function saveAttendanceRecord(
        int $sessionId, int $studentId, string $code, float $lat, float $lng
    ): AttendanceSubmission|string {
        return AttendanceSubmission::submitAttendance($sessionId, $studentId, $code, $lat, $lng);
    }
}
