<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Class Enrollments — links students to class_ids
        Schema::create('class_enrollments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->restrictOnDelete();
            $table->unsignedInteger('class_id');
            $table->string('semester', 10);
            $table->enum('status', ['enrolled', 'dropped'])->default('enrolled');
            $table->timestamps();

            $table->index('student_id');
            $table->index('class_id');
        });

        // SAMS-PACK-403 — Campus Boundary
        Schema::create('campus_boundaries', function (Blueprint $table) {
            $table->increments('campus_boundary_id');
            $table->string('campus_name', 100);
            $table->decimal('center_latitude', 10, 8);
            $table->decimal('center_longitude', 11, 8);
            $table->unsignedInteger('allowed_radius_meter');
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->timestamps();
        });

        // SAMS-PACK-404 — Attendance Session
        Schema::create('attendance_sessions', function (Blueprint $table) {
            $table->increments('attendance_session_id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('schedule_id');
            $table->foreignId('lecturer_id')->constrained('users')->restrictOnDelete();
            $table->unsignedInteger('campus_boundary_id');
            $table->string('attendance_code', 10)->unique();
            $table->date('session_date');
            $table->dateTime('started_at');
            $table->dateTime('closed_at')->nullable();
            $table->enum('status', ['active', 'closed'])->default('active');
            $table->timestamps();

            $table->foreign('schedule_id')->references('schedule_id')->on('class_schedules')->restrictOnDelete();
            $table->foreign('campus_boundary_id')->references('campus_boundary_id')->on('campus_boundaries')->restrictOnDelete();
            $table->index('status');
        });

        // SAMS-PACK-405 — Attendance Submission
        Schema::create('attendance_submissions', function (Blueprint $table) {
            $table->increments('attendance_submission_id');
            $table->unsignedInteger('attendance_session_id');
            $table->foreignId('student_id')->constrained('users')->restrictOnDelete();
            $table->string('submitted_code', 10);
            $table->dateTime('submitted_at');
            $table->decimal('gps_latitude', 10, 8);
            $table->decimal('gps_longitude', 11, 8);
            $table->enum('attendance_status', ['present', 'rejected'])->default('present');
            $table->timestamps();

            $table->foreign('attendance_session_id')->references('attendance_session_id')->on('attendance_sessions')->restrictOnDelete();
            // Prevent duplicate submission per session per student
            $table->unique(['attendance_session_id', 'student_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_submissions');
        Schema::dropIfExists('attendance_sessions');
        Schema::dropIfExists('campus_boundaries');
        Schema::dropIfExists('class_enrollments');
    }
};
