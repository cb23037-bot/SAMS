<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AttendanceSession;
use App\Models\CampusBoundary;
use App\Models\ClassAttendanceSubmission;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StudentAttendanceController extends Controller
{
    /**
     * List the class schedules the authenticated student is enrolled in,
     * along with whether each class currently has an active attendance session.
     */
    public function getSchedules(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $classIds = ClassEnrollment::getEnrolledClassIds($request->user()->id);

        $schedules = ClassSchedule::whereIn('class_id', $classIds)
            ->orderBy('schedule_date')
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'schedules' => $schedules->map(fn (ClassSchedule $schedule) => $this->formatSchedule($schedule, $request->user()->id)),
        ]);
    }

    /**
     * Check whether a class the student is enrolled in has an active attendance session.
     */
    public function getActiveSession(Request $request, int $scheduleId): JsonResponse
    {
        $this->requireStudent($request);

        $enrolledClassIds = ClassEnrollment::getEnrolledClassIds($request->user()->id);
        $schedule = ClassSchedule::where('schedule_id', $scheduleId)->firstOrFail();

        if (!in_array($schedule->class_id, $enrolledClassIds)) {
            abort(403, 'You are not enrolled in this class.');
        }

        $session = AttendanceSession::getActiveSessionForClass($schedule->class_id);

        if (!$session) {
            return response()->json(['session' => null]);
        }

        $alreadySubmitted = ClassAttendanceSubmission::hasSubmitted($session->attendance_session_id, $request->user()->id);

        return response()->json([
            'session' => [
                'attendance_session_id' => $session->attendance_session_id,
                'class_id' => $session->class_id,
                'schedule_id' => $session->schedule_id,
                'session_date' => $session->session_date,
                'started_at' => $session->started_at,
                'status' => $session->status,
                'already_submitted' => $alreadySubmitted,
            ],
        ]);
    }

    /**
     * Submit attendance for an active session using the attendance code and GPS location.
     */
    public function submitAttendance(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $validated = $request->validate([
            'schedule_id' => ['required', 'integer', 'exists:class_schedules,schedule_id'],
            'attendance_code' => ['required', 'string'],
            'gps_latitude' => ['required', 'numeric'],
            'gps_longitude' => ['required', 'numeric'],
        ]);

        $studentId = $request->user()->id;

        $enrolledClassIds = ClassEnrollment::getEnrolledClassIds($studentId);
        $schedule = ClassSchedule::where('schedule_id', $validated['schedule_id'])->firstOrFail();

        if (!in_array($schedule->class_id, $enrolledClassIds)) {
            abort(403, 'You are not enrolled in this class.');
        }

        $session = AttendanceSession::getActiveSessionForClass($schedule->class_id);

        if (!$session) {
            return response()->json([
                'message' => 'There is no active attendance session for this class right now.',
            ], 422);
        }

        if (ClassAttendanceSubmission::hasSubmitted($session->attendance_session_id, $studentId)) {
            return response()->json([
                'message' => 'You have already submitted your attendance for this session.',
            ], 422);
        }

        $submittedCode = strtoupper(trim($validated['attendance_code']));
        if ($submittedCode !== $session->attendance_code) {
            return response()->json([
                'message' => 'Invalid attendance code. Please check the code with your lecturer.',
            ], 422);
        }

        $withinBoundary = CampusBoundary::verifyLocation(
            (float) $validated['gps_latitude'],
            (float) $validated['gps_longitude'],
            $session->campus_boundary_id
        );

        $status = $withinBoundary ? 'present' : 'rejected';

        $submission = ClassAttendanceSubmission::create([
            'attendance_session_id' => $session->attendance_session_id,
            'student_id' => $studentId,
            'submitted_code' => $submittedCode,
            'submitted_at' => now(),
            'gps_latitude' => $validated['gps_latitude'],
            'gps_longitude' => $validated['gps_longitude'],
            'attendance_status' => $status,
        ]);

        if (!$withinBoundary) {
            return response()->json([
                'message' => 'Attendance rejected. You are outside the allowed campus area.',
                'submission' => $submission,
            ], 422);
        }

        return response()->json([
            'message' => 'Attendance marked successfully.',
            'submission' => $submission,
        ], 201);
    }

    private function formatSchedule(ClassSchedule $schedule, int $studentId): array
    {
        $activeSession = AttendanceSession::getActiveSessionForClass($schedule->class_id);
        $alreadySubmitted = false;

        if ($activeSession) {
            $alreadySubmitted = ClassAttendanceSubmission::hasSubmitted($activeSession->attendance_session_id, $studentId);
        }

        return [
            'schedule_id' => $schedule->schedule_id,
            'class_id' => $schedule->class_id,
            'course_code' => $schedule->course_code,
            'course_name' => $schedule->course_name,
            'class_name' => $schedule->class_name,
            'section' => $schedule->section,
            'semester' => $schedule->semester,
            'academic_session' => $schedule->academic_session,
            'day' => $schedule->day,
            'schedule_date' => $schedule->schedule_date,
            'start_time' => $schedule->start_time,
            'end_time' => $schedule->end_time,
            'venue' => $schedule->venue,
            'lecturer_name' => $schedule->lecturer->name ?? 'N/A',
            'has_active_session' => $activeSession !== null,
            'already_submitted' => $alreadySubmitted,
        ];
    }
}
