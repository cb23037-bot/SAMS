<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AttendanceSession;
use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class LecturerAttendanceController extends Controller
{
    /**
     * getAssignedSchedules(lecturer_id)
     *
     * Retrieves all class schedules assigned to the authenticated lecturer.
     * Uses lecturer_id from the authenticated user to filter schedules.
     * Called when the lecturer opens the Manage Attendance page.
     *
     * @param  Request $request — Authenticated lecturer request.
     * Returns: List<ClassSchedule> — All schedules assigned to the lecturer.
     */
    public function getSchedules(Request $request): JsonResponse
    {
        $this->requireLecturer($request);

        $schedules = ClassSchedule::getLecturerSchedules($request->user()->id);

        return response()->json([
            'schedules' => $schedules->map(fn (ClassSchedule $schedule) => $this->formatSchedule($schedule)),
        ]);
    }

    /**
     * List the authenticated lecturer's class schedules for today.
     */
    public function getTodaySchedules(Request $request): JsonResponse
    {
        $this->requireLecturer($request);

        $schedules = ClassSchedule::getTodaySchedules($request->user()->id);

        return response()->json([
            'schedules' => $schedules->map(fn (ClassSchedule $schedule) => $this->formatSchedule($schedule)),
        ]);
    }

    /**
     * Get the number of students enrolled in a given class schedule.
     */
    public function getEnrolledCount(Request $request, int $scheduleId): JsonResponse
    {
        $this->requireLecturer($request);

        $schedule = ClassSchedule::where('lecturer_id', $request->user()->id)
            ->where('schedule_id', $scheduleId)
            ->firstOrFail();

        return response()->json([
            'enrolled_count' => $schedule->countEnrolledStudents(),
        ]);
    }

    /**
     * startSession(schedule_id, lecturer_id)
     *
     * Creates a new active attendance session for the given class schedule.
     * Checks for an existing active session first — if one exists, returns it
     * with a message so the Flutter app can detect the [A1] flow.
     * Verifies an active campus boundary exists before creating the session.
     * Sets session_date to today and status to 'active'.
     *
     * @param  Request $request — Must contain schedule_id. lecturer_id is taken from auth.
     * Returns: AttendanceSession — The newly created (or existing) session.
     */
    public function startSession(Request $request): JsonResponse
    {
        $this->requireLecturer($request);

        $validated = $request->validate([
            'schedule_id' => ['required', 'integer', 'exists:class_schedules,schedule_id'],
        ]);

        $schedule = ClassSchedule::where('lecturer_id', $request->user()->id)
            ->where('schedule_id', $validated['schedule_id'])
            ->firstOrFail();

        $existing = AttendanceSession::getActiveSessionForClass($schedule->class_id);
        if ($existing) {
            return response()->json([
                'message' => 'An attendance session is already active for this class.',
                'session' => $this->formatSession($existing),
            ]);
        }

        $boundary = CampusBoundary::getActiveBoundary();
        if (!$boundary) {
            return response()->json([
                'message' => 'No active campus boundary is configured. Please contact the administrator.',
            ], 422);
        }

        $session = AttendanceSession::create([
            'class_id' => $schedule->class_id,
            'schedule_id' => $schedule->schedule_id,
            'lecturer_id' => $request->user()->id,
            'campus_boundary_id' => $boundary->campus_boundary_id,
            'attendance_code' => AttendanceSession::generateCode(),
            'session_date' => now()->toDateString(),
            'started_at' => now(),
            'status' => 'active',
        ]);

        return response()->json([
            'message' => 'Attendance session started.',
            'session' => $this->formatSession($session),
        ], 201);
    }

    /**
     * generateCode(attendance_session_id)
     *
     * Generates a new unique 6-character attendance code for the given session
     * and saves it, replacing any previously generated code.
     * The session must be active and owned by the authenticated lecturer.
     * Called when the lecturer taps "Generate Attendance Code" or "New Code".
     *
     * @param  Request $request    — Authenticated lecturer request.
     * @param  int     $sessionId  — The attendance session to generate a code for.
     * Returns: String — The newly generated attendance code.
     */
    public function generateCode(Request $request, int $sessionId): JsonResponse
    {
        $this->requireLecturer($request);

        $session = AttendanceSession::where('lecturer_id', $request->user()->id)
            ->where('attendance_session_id', $sessionId)
            ->where('status', 'active')
            ->firstOrFail();

        $session->attendance_code = AttendanceSession::generateCode();
        $session->save();

        return response()->json([
            'message' => 'New attendance code generated.',
            'session' => $this->formatSession($session),
        ]);
    }

    /**
     * getLiveSubmissions(attendance_session_id)
     *
     * Retrieves the live list of student attendance submissions for an active
     * session, along with the enrolled student count and present count.
     * Polled every 5 seconds by the lecturer's active session page.
     * Returns both present and rejected submissions ordered by submitted_at.
     *
     * @param  Request $request    — Authenticated lecturer request.
     * @param  int     $sessionId  — The attendance session to retrieve submissions for.
     * Returns: List<AttendanceSubmission> — All submissions with student details.
     */
    public function getLiveSubmissions(Request $request, int $sessionId): JsonResponse
    {
        $this->requireLecturer($request);

        $session = AttendanceSession::where('lecturer_id', $request->user()->id)
            ->where('attendance_session_id', $sessionId)
            ->firstOrFail();

        $schedule = $session->schedule;
        $enrolledCount = $schedule ? $schedule->countEnrolledStudents() : 0;

        $submissions = $session->submissions()->with('student')->orderByDesc('submitted_at')->get();

        return response()->json([
            'session' => $this->formatSession($session),
            'enrolled_count' => $enrolledCount,
            'submitted_count' => $submissions->where('attendance_status', 'present')->count(),
            'submissions' => $submissions->map(fn ($submission) => $this->formatSubmission($submission)),
        ]);
    }

    /**
     * closeSession(attendance_session_id)
     *
     * Closes the active attendance session by setting its status to 'closed'
     * and recording the closed_at timestamp.
     * After this, students can no longer submit attendance for the session.
     * The session must be active and owned by the authenticated lecturer.
     *
     * @param  Request $request    — Authenticated lecturer request.
     * @param  int     $sessionId  — The attendance session to close.
     * Returns: Boolean — true (HTTP 200) if closed successfully.
     */
    public function closeSession(Request $request, int $sessionId): JsonResponse
    {
        $this->requireLecturer($request);

        $session = AttendanceSession::where('lecturer_id', $request->user()->id)
            ->where('attendance_session_id', $sessionId)
            ->where('status', 'active')
            ->firstOrFail();

        $session->closeSession();

        return response()->json([
            'message' => 'Attendance session closed.',
            'session' => $this->formatSession($session),
        ]);
    }

    /**
     * viewRecord(attendance_session_id)
     *
     * Retrieves the full attendance record for a session, including present
     * students (with submission details), rejected submissions, and absent
     * students (enrolled but did not submit).
     * Called when the lecturer views the attendance record after closing a session.
     *
     * @param  Request $request    — Authenticated lecturer request.
     * @param  int     $sessionId  — The attendance session to retrieve records for.
     * Returns: List<AttendanceSubmission> — present, rejected, and absent lists.
     */
    public function viewRecord(Request $request, int $sessionId): JsonResponse
    {
        $this->requireLecturer($request);

        $session = AttendanceSession::where('lecturer_id', $request->user()->id)
            ->where('attendance_session_id', $sessionId)
            ->with(['schedule', 'submissions.student'])
            ->firstOrFail();

        $presentStudentIds = $session->submissions
            ->where('attendance_status', 'present')
            ->pluck('student_id')
            ->toArray();

        $enrolledStudentIds = $session->schedule
            ? ClassEnrollment::where('class_id', $session->schedule->class_id)
                ->where('status', 'enrolled')
                ->pluck('student_id')
                ->toArray()
            : [];

        $absentStudentIds = array_diff($enrolledStudentIds, $presentStudentIds);
        $absentStudents = \App\Models\User::whereIn('id', $absentStudentIds)->get();

        return response()->json([
            'session' => $this->formatSession($session),
            'present' => $session->submissions->where('attendance_status', 'present')->map(
                fn ($submission) => $this->formatSubmission($submission)
            )->values(),
            'rejected' => $session->submissions->where('attendance_status', 'rejected')->map(
                fn ($submission) => $this->formatSubmission($submission)
            )->values(),
            'absent' => $absentStudents->map(fn ($student) => [
                'student_id' => $student->id,
                'name' => $student->name,
                'matric_no' => $student->student_id,
            ])->values(),
        ]);
    }

    private function formatSchedule(ClassSchedule $schedule): array
    {
        $activeSession = AttendanceSession::getActiveSessionForClass($schedule->class_id);

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
            'enrolled_count' => $schedule->countEnrolledStudents(),
            'active_session' => $activeSession ? $this->formatSession($activeSession) : null,
        ];
    }

    private function formatSession(AttendanceSession $session): array
    {
        return [
            'attendance_session_id' => $session->attendance_session_id,
            'class_id' => $session->class_id,
            'schedule_id' => $session->schedule_id,
            'attendance_code' => $session->attendance_code,
            'session_date' => $session->session_date,
            'started_at' => $session->started_at,
            'closed_at' => $session->closed_at,
            'status' => $session->status,
        ];
    }

    private function formatSubmission($submission): array
    {
        return [
            'attendance_submission_id' => $submission->attendance_submission_id,
            'student_id' => $submission->student_id,
            'student_name' => $submission->student->name ?? 'Unknown',
            'matric_no' => $submission->student->student_id ?? 'N/A',
            'submitted_code' => $submission->submitted_code,
            'submitted_at' => $submission->submitted_at,
            'gps_latitude' => $submission->gps_latitude,
            'gps_longitude' => $submission->gps_longitude,
            'attendance_status' => $submission->attendance_status,
        ];
    }
}
