<?php

namespace App\Http\Controllers\Api;

use App\Models\Subject;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class SubjectController extends Controller
{
    // Fetches all subjects for your _fetchSubjects() method
    public function index()
    {
        // Use 'with' to load the sections alongside the subjects
        return Subject::with(['lectureSections', 'labSections'])
            ->orderBy('code', 'asc')
            ->get();
    }

    // Handles logic from AddSubjectPage
    public function store(Request $request)
    {
        return DB::transaction(function () use ($request) {
            // 1. Create the Subject
            $subject = Subject::create($request->only(['code', 'name', 'credit_hours']));

            // 2. Save Lecture Sections
            if ($request->has('lecture_sections')) {
                $subject->lectureSections()->createMany($request->lecture_sections);
            }

            // 3. Save Lab Sections
            if ($request->has('lab_sections')) {
                $subject->labSections()->createMany($request->lab_sections);
            }

            return response()->json(['message' => 'Subject created successfully'], 201);
        });
    }

    public function getSections($subjectId) {
    return response()->json([
        'lectures' => \App\Models\LectureSection::where('subject_id', $subjectId)->get(),
        'labs' => \App\Models\LabSection::where('subject_id', $subjectId)->get(),
    ]);
    }

    // Handles the delete action from your _deleteSubject() method
    public function destroy($id)
    {
        $subject = Subject::findOrFail($id);
        $subject->delete();
        return response()->json(['message' => 'Subject deleted successfully']);
    }
}
