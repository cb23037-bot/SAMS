<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AttendanceSession;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;

class AttendanceReportController extends Controller
{
    /**
     * List the classes the authenticated lecturer can generate a report for.
     */
    public function getFilters(Request $request): JsonResponse
    {
        $this->requireLecturer($request);

        $schedules = ClassSchedule::where('lecturer_id', $request->user()->id)->get();

        $classes = $schedules->unique('class_id')->map(fn (ClassSchedule $schedule) => [
            'class_id' => $schedule->class_id,
            'course_code' => $schedule->course_code,
            'course_name' => $schedule->course_name,
            'class_name' => $schedule->class_name,
            'section' => $schedule->section,
        ])->values();

        return response()->json(['classes' => $classes]);
    }

    /**
     * Generate an attendance report summary for a class.
     */
    public function generateReport(Request $request): JsonResponse
    {
        $this->requireLecturer($request);

        $validated = $request->validate([
            'class_id' => ['required', 'integer'],
        ]);

        return response()->json($this->buildReport($request->user()->id, $validated['class_id']));
    }

    /**
     * Download the attendance report for a class as a CSV file.
     */
    public function downloadReport(Request $request)
    {
        $this->requireLecturer($request);

        $validated = $request->validate([
            'class_id' => ['required', 'integer'],
        ]);

        $report = $this->buildReport($request->user()->id, $validated['class_id']);

        $sessionDates = array_map(fn ($session) => $session['session_date'], $report['sessions']);

        $headers = array_merge(['Matric No', 'Student Name'], $sessionDates, ['Present', 'Total', 'Percentage']);

        $rows = [$headers];
        foreach ($report['students'] as $student) {
            $row = [$student['matric_no'], $student['name']];
            foreach ($student['attendance'] as $status) {
                $row[] = $status === 'present' ? 'P' : 'A';
            }
            $row[] = $student['present_count'];
            $row[] = $student['total_sessions'];
            $row[] = $student['percentage'] . '%';
            $rows[] = $row;
        }

        $callback = function () use ($rows) {
            $handle = fopen('php://output', 'w');
            foreach ($rows as $row) {
                fputcsv($handle, $row);
            }
            fclose($handle);
        };

        $filename = 'attendance_report_class_' . $validated['class_id'] . '.csv';

        return Response::stream($callback, 200, [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => 'attachment; filename="' . $filename . '"',
        ]);
    }

    private function buildReport(int $lecturerId, int $classId): array
    {
        $schedule = ClassSchedule::where('lecturer_id', $lecturerId)
            ->where('class_id', $classId)
            ->first();

        if (!$schedule) {
            abort(404, 'Class not found.');
        }

        $sessions = AttendanceSession::where('class_id', $classId)
            ->where('lecturer_id', $lecturerId)
            ->orderBy('session_date')
            ->with('submissions')
            ->get();

        $enrolledStudents = ClassEnrollment::where('class_id', $classId)
            ->where('status', 'enrolled')
            ->with('student')
            ->get();

        $sessionSummaries = $sessions->map(function (AttendanceSession $session) {
            $present = $session->submissions->where('attendance_status', 'present')->count();

            return [
                'attendance_session_id' => $session->attendance_session_id,
                'session_date' => $session->session_date,
                'status' => $session->status,
                'present_count' => $present,
            ];
        })->values();

        $students = $enrolledStudents->map(function (ClassEnrollment $enrollment) use ($sessions) {
            $presentCount = 0;
            $attendance = $sessions->map(function (AttendanceSession $session) use ($enrollment, &$presentCount) {
                $submission = $session->submissions->firstWhere('student_id', $enrollment->student_id);
                $isPresent = $submission && $submission->attendance_status === 'present';
                if ($isPresent) {
                    $presentCount++;
                }
                return $isPresent ? 'present' : 'absent';
            })->values();

            $totalSessions = $sessions->count();
            $percentage = $totalSessions > 0 ? round(($presentCount / $totalSessions) * 100, 1) : 0;

            return [
                'student_id' => $enrollment->student_id,
                'matric_no' => $enrollment->student->student_id ?? 'N/A',
                'name' => $enrollment->student->name ?? 'Unknown',
                'attendance' => $attendance,
                'present_count' => $presentCount,
                'total_sessions' => $totalSessions,
                'percentage' => $percentage,
            ];
        })->values();

        return [
            'class' => [
                'class_id' => $schedule->class_id,
                'course_code' => $schedule->course_code,
                'course_name' => $schedule->course_name,
                'class_name' => $schedule->class_name,
                'section' => $schedule->section,
            ],
            'sessions' => $sessionSummaries,
            'students' => $students,
        ];
    }
}
