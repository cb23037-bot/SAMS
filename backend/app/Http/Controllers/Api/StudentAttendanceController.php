<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AttendanceSession;
use App\Models\CampusBoundary;
use App\Models\AttendanceSubmission;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StudentAttendanceController extends Controller
{
    /**
     * getEnrolledSchedules(student_id)
     *
     * Retrieves all class schedules for the classes the authenticated student
     * is enrolled in. Each schedule includes a flag indicating whether an
     * active attendance session currently exists and whether the student has
     * already submitted for it.
     * Called when the student opens the Mark Attendance page.
     *
     * @param  Request $request — Authenticated student request. student_id from auth.
     * Returns: List<ClassSchedule> — Enrolled class schedules with session status.
     */
    public function getEnrolledSchedules(Request $request): JsonResponse
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
     * getActiveSession(student_id, schedule_id)
     *
     * Retrieves the currently active attendance session for a class schedule
     * the student is enrolled in. Verifies that the student is actually enrolled
     * before returning session details. Also checks if the student has already
     * submitted for this session.
     * Called when the student opens the attendance submission form.
     *
     * @param  Request $request    — Authenticated student request. student_id from auth.
     * @param  int     $scheduleId — The class schedule to check for an active session.
     * Returns: AttendanceSession — The active session with already_submitted flag, or null.
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

        $alreadySubmitted = AttendanceSubmission::hasSubmitted($session->attendance_session_id, $request->user()->id);

        return response()->json([
            'session' => [
                'attendance_session_id' => $session->attendance_session_id,
                'class_id'              => $session->class_id,
                'schedule_id'           => $session->schedule_id,
                'session_date'          => $session->session_date,
                'started_at'            => $session->started_at,
                'status'                => $session->status,
                'already_submitted'     => $alreadySubmitted,
            ],
        ]);
    }

    /**
     * submitAttendance(student_id, attendance_code, gps_latitude, gps_longitude)
     *
     * Processes a student's attendance submission for an active session.
     * Runs the full verification pipeline in order:
     *   1. Checks the session is still active.
     *   2. verifyAttendanceCode()  — validates the entered code.
     *   3. verifyGPSLocation()     — checks the student is within campus.
     *   4. checkDuplicateSubmission() — prevents double submission.
     *   5. saveAttendanceRecord()  — persists the submission as 'present'.
     *
     * @param  Request $request — Must contain schedule_id, attendance_code,
     *                            gps_latitude, gps_longitude. student_id from auth.
     * Returns: Boolean — true (HTTP 201) if submission saved, error response otherwise.
     */
    public function submitAttendance(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $validated = $request->validate([
            'schedule_id'     => ['required', 'integer', 'exists:class_schedules,schedule_id'],
            'attendance_code' => ['required', 'string'],
            'gps_latitude'    => ['required', 'numeric'],
            'gps_longitude'   => ['required', 'numeric'],
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
                'message' => 'Attendance session has ended.',
            ], 422);
        }

        // Step 6 [A2]: verifyAttendanceCode()
        $submittedCode = strtoupper(trim($validated['attendance_code']));
        if (!$this->verifyAttendanceCode($submittedCode, $session->attendance_code)) {
            return response()->json([
                'message' => 'Invalid attendance code. Please check the code with your lecturer.',
            ], 422);
        }

        // Step 9 [E2]: verifyGPSLocation()
        if (!$this->verifyGPSLocation(
            (float) $validated['gps_latitude'],
            (float) $validated['gps_longitude'],
            $session->campus_boundary_id
        )) {
            return response()->json([
                'message' => 'Attendance can only be submitted within campus area.',
            ], 422);
        }

        // Step 10 [A4]: checkDuplicateSubmission()
        if ($this->checkDuplicateSubmission($session->attendance_session_id, $studentId)) {
            return response()->json([
                'message' => 'You have already submitted your attendance for this session.',
            ], 422);
        }

        // Step 11: saveAttendanceRecord()
        $submission = $this->saveAttendanceRecord(
            $session->attendance_session_id,
            $studentId,
            $submittedCode,
            (float) $validated['gps_latitude'],
            (float) $validated['gps_longitude']
        );

        return response()->json([
            'message'    => 'Attendance submitted successfully.',
            'submission' => $submission,
        ], 201);
    }

    /**
     * verifyAttendanceCode(attendance_code)
     *
     * Verifies that the code entered by the student matches the active session's
     * attendance code. Comparison is case-insensitive (both sides uppercased).
     * Called during the submitAttendance() pipeline before GPS verification.
     *
     * @param  string $submittedCode — The code entered by the student (already uppercased).
     * @param  string $sessionCode   — The correct code stored on the session.
     * Returns: Boolean — true if codes match, false otherwise.
     */
    private function verifyAttendanceCode(string $submittedCode, string $sessionCode): bool
    {
        return $submittedCode === strtoupper($sessionCode);
    }

    /**
     * verifyGPSLocation(gps_latitude, gps_longitude)
     *
     * Checks whether the student's GPS coordinates are within the campus
     * boundary radius attached to the session. Delegates to
     * CampusBoundary::verifyLocation() which applies the Haversine formula.
     * Called during the submitAttendance() pipeline after code verification.
     *
     * @param  float $latitude    — Student's GPS latitude at time of submission.
     * @param  float $longitude   — Student's GPS longitude at time of submission.
     * @param  int   $boundaryId  — The campus boundary ID to check against.
     * Returns: Boolean — true if within allowed radius, false otherwise.
     */
    private function verifyGPSLocation(float $latitude, float $longitude, int $boundaryId): bool
    {
        return CampusBoundary::verifyLocation($latitude, $longitude, $boundaryId);
    }

    /**
     * checkDuplicateSubmission(attendance_session_id, student_id)
     *
     * Checks whether the student has already submitted attendance for the
     * given session to prevent duplicate records.
     * Called during the submitAttendance() pipeline after GPS verification.
     *
     * @param  int $sessionId — The attendance session ID to check.
     * @param  int $studentId — The student ID to check.
     * Returns: Boolean — true if a submission already exists, false otherwise.
     */
    private function checkDuplicateSubmission(int $sessionId, int $studentId): bool
    {
        return AttendanceSubmission::hasSubmitted($sessionId, $studentId);
    }

    /**
     * saveAttendanceRecord(attendance_session_id, student_id, submitted_code,
     *                      gps_latitude, gps_longitude)
     *
     * Persists a new attendance submission record with status 'present'.
     * Records the submitted code, GPS coordinates, and the current timestamp.
     * Called as the final step in the submitAttendance() pipeline after all
     * verifications have passed.
     *
     * @param  int    $sessionId     — The attendance session being submitted to.
     * @param  int    $studentId     — The student submitting attendance.
     * @param  string $submittedCode — The uppercased attendance code entered by the student.
     * @param  float  $latitude      — Student's GPS latitude.
     * @param  float  $longitude     — Student's GPS longitude.
     * Returns: Boolean (AttendanceSubmission) — The saved submission record.
     */
    private function saveAttendanceRecord(
        int $sessionId,
        int $studentId,
        string $submittedCode,
        float $latitude,
        float $longitude
    ): AttendanceSubmission {
        return AttendanceSubmission::create([
            'attendance_session_id' => $sessionId,
            'student_id'            => $studentId,
            'submitted_code'        => $submittedCode,
            'submitted_at'          => now(),
            'gps_latitude'          => $latitude,
            'gps_longitude'         => $longitude,
            'attendance_status'     => 'present',
        ]);
    }

    private function formatSchedule(ClassSchedule $schedule, int $studentId): array
    {
        $activeSession    = AttendanceSession::getActiveSessionForClass($schedule->class_id);
        $alreadySubmitted = false;

        if ($activeSession) {
            $alreadySubmitted = AttendanceSubmission::hasSubmitted($activeSession->attendance_session_id, $studentId);
        }

        return [
            'schedule_id'      => $schedule->schedule_id,
            'class_id'         => $schedule->class_id,
            'course_code'      => $schedule->course_code,
            'course_name'      => $schedule->course_name,
            'class_name'       => $schedule->class_name,
            'section'          => $schedule->section,
            'semester'         => $schedule->semester,
            'academic_session' => $schedule->academic_session,
            'day'              => $schedule->day,
            'schedule_date'    => $schedule->schedule_date,
            'start_time'       => $schedule->start_time,
            'end_time'         => $schedule->end_time,
            'venue'            => $schedule->venue,
            'lecturer_name'    => $schedule->lecturer->name ?? 'N/A',
            'has_active_session' => $activeSession !== null,
            'already_submitted'  => $alreadySubmitted,
        ];
    }
}
