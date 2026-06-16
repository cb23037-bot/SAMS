<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\SubjectRegistration;
use App\Models\Subject;
use App\Models\AcademicSession;
use Illuminate\Support\Facades\Log;

class SubjectRegistrationController extends Controller
{
    public function index(Request $request) {
        return response()->json([
            'registrations' => $request->user()->subjectRegistrations() 
                ->where('status', 'approved') 
                ->with('subject') 
                ->get()
        ]);
    }

    public function store(Request $request) {
        $validated = $request->validate([
            'subject_id' => 'required|exists:subjects,id',
            'lecture_section' => 'required|string',
            'lecture_instructor' => 'nullable|string',
            'lecture_schedule' => 'nullable|string',
            'lab_section' => 'nullable|string',
            'lab_instructor' => 'nullable|string',
            'lab_schedule' => 'nullable|string',
        ]);

        $userId = $request->user()->id;

        // Check for Lecture clash
        if (!empty($validated['lecture_schedule']) && $this->isTimeClashing($userId, $validated['lecture_schedule'])) {
            return response()->json(['message' => 'Lecture time clash detected!'], 422);
        }

        // Check for Lab clash
        if (!empty($validated['lab_schedule']) && $this->isTimeClashing($userId, $validated['lab_schedule'])) {
            return response()->json(['message' => 'Lab time clash detected!'], 422);
        }

        $validated['user_id'] = $userId;
        $registration = SubjectRegistration::create($validated);

        return response()->json([
            'message' => 'Registration successful',
            'registration' => $registration
        ], 201);
    }

    private function isTimeClashing($userId, $newSchedule)
    {
        // Parse new schedule: "Monday 08:00-10:00"
        $new = $this->parseSchedule($newSchedule);
        if (!$new) return false;

        $existingRegistrations = SubjectRegistration::where('user_id', $userId)
            ->whereIn('status', ['pending', 'approved'])
            ->get();

        foreach ($existingRegistrations as $reg) {
            foreach ([$reg->lecture_schedule, $reg->lab_schedule] as $s) {
                $exist = $this->parseSchedule($s);
                if (!$exist) continue;

                // Clash Logic: Same Day AND (StartA < EndB AND EndA > StartB)
                if ($new['day'] === $exist['day'] && $new['start'] < $exist['end'] && $new['end'] > $exist['start']) {
                    return true;
                }
            }
        }
        return false;
    }

    private function parseSchedule($schedule)
    {
        if (empty($schedule)) return null;
        $parts = explode(' ', $schedule);
        if (count($parts) < 2) return null;
        
        $day = $parts[0];
        $times = explode('-', $parts[1]);
        if (count($times) !== 2) return null;

        return [
            'day' => $day,
            'start' => $this->timeToMinutes($times[0]),
            'end' => $this->timeToMinutes($times[1]),
        ];
    }

    private function timeToMinutes($time)
    {
        $t = explode(':', $time);
        return (int)$t[0] * 60 + (int)$t[1];
    }

    public function submitRegistration(Request $request) {
        $registrations = SubjectRegistration::where('user_id', $request->user()->id)
            ->where('status', 'pending')
            ->get();

        if ($registrations->isEmpty()) {
            return response()->json(['message' => 'No pending registrations to submit.'], 400);
        }

        SubjectRegistration::where('user_id', $request->user()->id)
            ->where('status', 'pending')
            ->update(['status' => 'submitted']);

        return response()->json(['message' => 'Registration submitted to PA successfully.']);
    }

    public function getPendingApprovals() {
        $pendingStudents = SubjectRegistration::where('status', 'submitted') 
            ->with('user')
            ->get()
            ->unique('user_id')
            ->map(function ($reg) {
                return [
                    'user_id' => $reg->user_id,
                    'student_name' => $reg->user->name ?? 'Unknown Student',
                    'student_id' => $reg->user->student_id ?? 'N/A',
                ];
            })->values();

        return response()->json(['students' => $pendingStudents]); 
    }

    public function getStudentPendingSubjects($studentId) {
        $registrations = SubjectRegistration::where('user_id', $studentId)
            ->where('status', 'submitted')
            ->with(['subject', 'user'])
            ->get();
            
        return response()->json(['subjects' => $registrations]);
    }

    public function approveAll(Request $request, $studentId) 
    {
        SubjectRegistration::where('user_id', $studentId)
            ->where('status', 'submitted')
            ->update(['status' => 'approved']);

        return response()->json(['message' => 'All registrations approved successfully.']);
    }

    public function updateStatus(Request $request, $id) 
    {
        $request->validate(['status' => 'required|in:approved,rejected']);
        $registration = SubjectRegistration::findOrFail($id);
        $registration->status = $request->status;
        $registration->save();

        return response()->json([
            'message' => 'Registration ' . $request->status . ' successfully',
            'registration' => $registration
        ]);
    }

    public function destroy($id) {
        SubjectRegistration::where('user_id', auth()->id())->findOrFail($id)->delete();
        return response()->json(['message' => 'Registration removed successfully']);
    }
}