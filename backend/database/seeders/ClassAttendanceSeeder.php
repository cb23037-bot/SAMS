<?php

namespace Database\Seeders;

use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use App\Models\User;
use Illuminate\Database\Seeder;

class ClassAttendanceSeeder extends Seeder
{
    public function run(): void
    {
        $boundary = CampusBoundary::query()->updateOrCreate(
            ['campus_name' => 'UMPSA Pekan Campus'],
            [
                'center_latitude' => 3.5375,
                'center_longitude' => 103.4239,
                'allowed_radius_meter' => 500,
                'status' => 'active',
            ]
        );

        $lecturer = User::where('email', 'lecturer@adab.umpsa.edu.my')->first();

        if (!$lecturer) {
            return;
        }

        $today = now();

        $schedules = [
            [
                'class_id' => 1,
                'course_code' => 'CSC3700',
                'course_name' => 'Software Engineering',
                'class_name' => 'Software Engineering',
                'section' => '01',
                'semester' => 'Semester 6',
                'academic_session' => '2025/2026',
                'day' => $today->format('l'),
                'schedule_date' => $today->toDateString(),
                'start_time' => '08:00',
                'end_time' => '10:00',
                'venue' => 'Bilik Kuliah 1',
            ],
            [
                'class_id' => 2,
                'course_code' => 'CSC3801',
                'course_name' => 'Mobile Application Development',
                'class_name' => 'Mobile Application Development',
                'section' => '01',
                'semester' => 'Semester 6',
                'academic_session' => '2025/2026',
                'day' => $today->copy()->addDay()->format('l'),
                'schedule_date' => $today->copy()->addDay()->toDateString(),
                'start_time' => '10:00',
                'end_time' => '12:00',
                'venue' => 'Bilik Kuliah 2',
            ],
        ];

        foreach ($schedules as $schedule) {
            ClassSchedule::query()->updateOrCreate(
                [
                    'class_id' => $schedule['class_id'],
                    'schedule_date' => $schedule['schedule_date'],
                ],
                array_merge($schedule, ['lecturer_id' => $lecturer->id])
            );
        }

        $students = User::where('role', 'student')
            ->whereIn('student_id', ['CB23037', 'CB23022', 'CB23065', 'CB23111'])
            ->get();

        foreach ($students as $student) {
            foreach ([1, 2] as $classId) {
                ClassEnrollment::query()->updateOrCreate(
                    [
                        'student_id' => $student->id,
                        'class_id' => $classId,
                    ],
                    [
                        'semester' => '6',
                        'status' => 'enrolled',
                    ]
                );
            }
        }
    }
}
