<?php

namespace App\Http\Controllers;

use App\Models\AttendanceSession;
use App\Models\AttendanceSubmission;
use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

// SAMS-PACK-415 — StudentAttendanceController
class StudentAttendanceController extends Controller
{
    // SAMS-PACK-415: getEnrolledSchedules(student_id)
    // GET /api/student/schedules
    public function getEnrolledSchedules(Request $request): JsonResponse
    {
        $studentId  = $request->user()->id;
        $classIds   = ClassEnrollment::getEnrolledClassIds($studentId);

        $schedules = ClassSchedule::whereIn('class_id', $classIds)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();

        // Attach active session flag per schedule
        $schedules = $schedules->map(function ($schedule) use ($studentId) {
            $activeSession = AttendanceSession::getActiveSession($schedule->schedule_id);
            $schedule->active_session     = $activeSession;
            $schedule->already_submitted  = $activeSession
                ? AttendanceSubmission::checkDuplicateSubmission(
                    $activeSession->attendance_session_id, $studentId
                  )
                : false;
            return $schedule;
        });

        return response()->json(['schedules' => $schedules]);
    }

    // SAMS-PACK-415: getActiveSession(student_id, schedule_id)
    // GET /api/student/schedules/{scheduleId}/active-session
    public function getActiveSession(Request $request, int $scheduleId): JsonResponse
    {
        // Verify enrollment
        $studentId = $request->user()->id;
        $schedule  = ClassSchedule::find($scheduleId);

        if (!$schedule) {
            return response()->json(['message' => 'Schedule not found.'], 404);
        }

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
            'session'          => $session,
            'already_submitted' => $alreadySubmitted,
        ]);
    }

    // SAMS-PACK-415: submitAttendance(student_id, attendance_code, gps_latitude, gps_longitude)
    // POST /api/student/attendance/submit
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

        // SAMS-REQ-416: Check active session
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

    // SAMS-PACK-415: verifyAttendanceCode(attendance_code)
    private function verifyAttendanceCode(string $inputCode, string $sessionCode): bool
    {
        return $inputCode === $sessionCode;
    }

    // SAMS-PACK-415: verifyGPSLocation(gps_latitude, gps_longitude)
    private function verifyGPSLocation(float $lat, float $lng, int $boundaryId): bool
    {
        return CampusBoundary::verifyLocation($lat, $lng, $boundaryId);
    }

    // SAMS-PACK-415: checkDuplicateSubmission(attendance_session_id, student_id)
    private function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return AttendanceSubmission::checkDuplicateSubmission($sessionId, $studentId);
    }

    // SAMS-PACK-415: saveAttendanceRecord(attendance_session_id, student_id, submitted_code, gps_latitude, gps_longitude)
    private function saveAttendanceRecord(
        int $sessionId, int $studentId, string $code, float $lat, float $lng
    ): AttendanceSubmission|string {
        return AttendanceSubmission::submitAttendance($sessionId, $studentId, $code, $lat, $lng);
    }
}
