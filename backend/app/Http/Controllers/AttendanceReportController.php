<?php

namespace App\Http\Controllers;

use App\Models\AttendanceSession;
use App\Models\AttendanceSubmission;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;

// SAMS-PACK-416 — AttendanceReportController
class AttendanceReportController extends Controller
{
    // SAMS-PACK-416: getReportFilter(lecturer_id)
    // GET /api/lecturer/report/filter
    // FIX: this endpoint is now properly called by the Flutter report screen
    public function getReportFilter(Request $request): JsonResponse
    {
        $lecturerId = $request->user()->id;
        $schedules  = ClassSchedule::getLecturerSchedules($lecturerId);
        return response()->json(['schedules' => $schedules]);
    }

    // SAMS-PACK-416: generateReport(schedule_id, session_date)
    // GET /api/lecturer/report?schedule_id=1&session_date=2026-05-10
    public function generateReport(Request $request): JsonResponse
    {
        $request->validate([
            'schedule_id'  => 'required|integer',
            'session_date' => 'required|date',
        ]);

        $lecturerId  = $request->user()->id;
        $scheduleId  = $request->schedule_id;
        $sessionDate = $request->session_date;

        // SAMS-PACK-402: verifyLecturerSchedule
        if (!ClassSchedule::verifyLecturerSchedule($scheduleId, $lecturerId)) {
            return response()->json(['message' => 'Unauthorized access to attendance report.'], 403);
        }

        $schedule = ClassSchedule::find($scheduleId);

        // Find attendance session
        $session = AttendanceSession::where('schedule_id', $scheduleId)
            ->whereDate('session_date', $sessionDate)
            ->first();

        if (!$session) {
            return response()->json(['message' => 'No attendance session found for the selected class and date.'], 404);
        }

        // SAMS-PACK-416: calculateSummary
        $totalStudents   = ClassEnrollment::countEnrolledStudents($schedule->class_id);
        $presentStudents = AttendanceSubmission::countPresentStudents($session->attendance_session_id);
        $absentStudents  = $totalStudents - $presentStudents;
        $percentage      = $totalStudents > 0
            ? round(($presentStudents / $totalStudents) * 100, 1)
            : 0;

        // Detailed records
        $detailedRecords = AttendanceSubmission::getSubmissionsBySession($session->attendance_session_id);

        return response()->json([
            'schedule'        => $schedule,
            'session'         => $session,
            'summary' => [
                'total_students'        => $totalStudents,
                'present_students'      => $presentStudents,
                'absent_students'       => $absentStudents,
                'attendance_percentage' => $percentage,
            ],
            'detailed_records' => $detailedRecords,
        ]);
    }

    // FIX: SAMS-REQ-414 — Download attendance report as CSV
    // GET /api/lecturer/report/download?schedule_id=1&session_date=2026-05-10
    public function downloadReport(Request $request): StreamedResponse|JsonResponse
    {
        $request->validate([
            'schedule_id'  => 'required|integer',
            'session_date' => 'required|date',
        ]);

        $lecturerId  = $request->user()->id;
        $scheduleId  = $request->schedule_id;
        $sessionDate = $request->session_date;

        if (!ClassSchedule::verifyLecturerSchedule($scheduleId, $lecturerId)) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $schedule = ClassSchedule::find($scheduleId);
        $session  = AttendanceSession::where('schedule_id', $scheduleId)
            ->whereDate('session_date', $sessionDate)
            ->first();

        if (!$session) {
            return response()->json(['message' => 'No attendance session found.'], 404);
        }

        $totalStudents   = ClassEnrollment::countEnrolledStudents($schedule->class_id);
        $presentStudents = AttendanceSubmission::countPresentStudents($session->attendance_session_id);
        $absentStudents  = $totalStudents - $presentStudents;
        $percentage      = $totalStudents > 0
            ? round(($presentStudents / $totalStudents) * 100, 1)
            : 0;

        $records  = AttendanceSubmission::getSubmissionsBySession($session->attendance_session_id);
        $filename = "attendance_{$schedule->course_code}_{$sessionDate}.csv";

        return response()->streamDownload(function () use ($schedule, $session, $records, $totalStudents, $presentStudents, $absentStudents, $percentage, $sessionDate) {
            $out = fopen('php://output', 'w');

            // Report header block
            fputcsv($out, ['SAMS — Attendance Report']);
            fputcsv($out, ['Course',  $schedule->course_name]);
            fputcsv($out, ['Code',    $schedule->course_code]);
            fputcsv($out, ['Section', $schedule->section]);
            fputcsv($out, ['Date',    $sessionDate]);
            fputcsv($out, ['Venue',   $schedule->venue]);
            fputcsv($out, []);

            // Summary block
            fputcsv($out, ['Summary']);
            fputcsv($out, ['Total Enrolled', $totalStudents]);
            fputcsv($out, ['Present',        $presentStudents]);
            fputcsv($out, ['Absent',         $absentStudents]);
            fputcsv($out, ['Attendance Rate', $percentage . '%']);
            fputcsv($out, []);

            // Detailed records header
            fputcsv($out, ['No.', 'Student Name', 'Matric No.', 'Submitted At', 'GPS Latitude', 'GPS Longitude', 'Status']);

            foreach ($records as $i => $record) {
                fputcsv($out, [
                    $i + 1,
                    $record->student->name       ?? '—',
                    $record->student->student_id ?? '—',
                    $record->submitted_at,
                    $record->gps_latitude,
                    $record->gps_longitude,
                    strtoupper($record->attendance_status),
                ]);
            }

            fclose($out);
        }, $filename, [
            'Content-Type'        => 'text/csv',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ]);
    }
}
