<?php

namespace Database\Seeders;

use App\Models\CampusBoundary;
use App\Models\ClassEnrollment;
use App\Models\ClassSchedule;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Campus boundary — UMPSA Main Campus
        CampusBoundary::create([
            'campus_name'          => 'UMPSA Main Campus',
            'center_latitude'      => 3.54558200,
            'center_longitude'     => 103.42862100,
            'allowed_radius_meter' => 1000,
            'status'               => 'active',
        ]);

        // Lecturer
        $lecturer = User::create([
            'name'     => 'Dr. Siti Norsyahida',
            'email'    => 'siti@umpsa.edu.my',
            'password' => Hash::make('password'),
            'role'     => 'lecturer',
            'status'   => 'active',
        ]);

        // Students
        $students = collect([
            ['name' => 'Ahmad Faris bin Ismail',       'email' => 'cb23001@umpsa.edu.my', 'student_id' => 'CB23001'],
            ['name' => 'Nurul Aina binti Rahman',       'email' => 'cb23002@umpsa.edu.my', 'student_id' => 'CB23002'],
            ['name' => 'Muhammad Haziq bin Zulkifli',   'email' => 'cb23003@umpsa.edu.my', 'student_id' => 'CB23003'],
            ['name' => 'Siti Hajar binti Mohd Noor',    'email' => 'cb23004@umpsa.edu.my', 'student_id' => 'CB23004'],
            ['name' => 'Lim Wei Xin',                   'email' => 'cb23005@umpsa.edu.my', 'student_id' => 'CB23005'],
        ])->map(fn($s) => User::create([
            'name'       => $s['name'],
            'email'      => $s['email'],
            'password'   => Hash::make('password'),
            'role'       => 'student',
            'student_id' => $s['student_id'],
            'course'     => 'Bachelor of Computer Science',
            'status'     => 'active',
        ]));

        // Class schedules
        $schedule1 = ClassSchedule::create([
            'class_id'         => 101,
            'lecturer_id'      => $lecturer->id,
            'course_code'      => 'BCS2243',
            'course_name'      => 'Database Management System',
            'class_name'       => 'CS2243-01',
            'section'          => 'Section 01',
            'semester'         => '1',
            'academic_session' => '202520261',
            'day'              => 'Monday',
            'schedule_date'    => today(),
            'start_time'       => '08:00:00',
            'end_time'         => '10:00:00',
            'venue'            => 'Lab A, Block C',
        ]);

        $schedule2 = ClassSchedule::create([
            'class_id'         => 102,
            'lecturer_id'      => $lecturer->id,
            'course_code'      => 'BCS3123',
            'course_name'      => 'Software Design Workshop',
            'class_name'       => 'CS3123-02',
            'section'          => 'Section 02',
            'semester'         => '1',
            'academic_session' => '202520261',
            'day'              => 'Tuesday',
            'schedule_date'    => today()->addDay(),
            'start_time'       => '14:00:00',
            'end_time'         => '16:00:00',
            'venue'            => 'DK5, Block A',
        ]);

        // Enroll all students in class 101
        foreach ($students as $student) {
            ClassEnrollment::create([
                'student_id' => $student->id,
                'class_id'   => 101,
                'semester'   => '202520261',
                'status'     => 'enrolled',
            ]);
        }

        // Enroll first 3 students in class 102
        foreach ($students->take(3) as $student) {
            ClassEnrollment::create([
                'student_id' => $student->id,
                'class_id'   => 102,
                'semester'   => '202520261',
                'status'     => 'enrolled',
            ]);
        }
    }
}
