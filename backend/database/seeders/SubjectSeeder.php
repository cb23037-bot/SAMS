<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class SubjectSeeder extends Seeder
{
    public function run(): void
{
    // 1. Software Engineering
    $seId = DB::table('subjects')->insertGetId([
        'name' => 'Software Engineering',
        'code' => 'SE101',
        'credit_hours' => 3,
        'created_at' => now(),
    ]);

    DB::table('lecture_sections')->insert([
        'subject_id' => $seId,
        'section' => '01',
        'lecturer' => 'Dr. Smith',
        'schedule' => 'Monday 08:00-10:00',
        'created_at' => now(),
    ]);

    DB::table('lab_sections')->insert([
        'subject_id' => $seId,
        'section' => 'L01',
        'instructor' => 'Mr. Jones',
        'schedule' => 'Tuesday 14:00-16:00',
        'created_at' => now(),
    ]);

    // 2. Database Systems
    $dbId = DB::table('subjects')->insertGetId([
        'name' => 'Database Systems',
        'code' => 'DB202',
        'credit_hours' => 3,
        'created_at' => now(),
    ]);

    DB::table('lecture_sections')->insert([
        'subject_id' => $dbId,
        'section' => '01',
        'lecturer' => 'Dr. Brown',
        'schedule' => 'Monday 10:00-12:00',
        'created_at' => now(),
    ]);
    DB::table('lab_sections')->insert([
        'subject_id' => $dbId,
        'section' => 'L01',
        'instructor' => 'Mr. Jones',
        'schedule' => 'Tuesday 14:00-16:00',
        'created_at' => now(),
    ]);

    // 3. Web Development (Clashing Case)
    $wdId = DB::table('subjects')->insertGetId([
        'name' => 'Web Development',
        'code' => 'WD303',
        'credit_hours' => 3,
        'created_at' => now(),
    ]);

    DB::table('lecture_sections')->insert([
        'subject_id' => $wdId,
        'section' => '01',
        'lecturer' => 'Dr. White',
        'schedule' => 'Monday 8:00-10:00',
        'created_at' => now(),
    ]);

    DB::table('lab_sections')->insert([
        'subject_id' => $wdId,
        'section' => 'L01',
        'instructor' => 'Mr. Jones',
        'schedule' => 'Tuesday 14:00-16:00',
        'created_at' => now(),
    ]);
}
}