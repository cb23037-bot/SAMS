<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('campus_boundaries', function (Blueprint $table) {
            $table->increments('campus_boundary_id');
            $table->string('campus_name', 100);
            $table->decimal('center_latitude', 10, 8);
            $table->decimal('center_longitude', 11, 8);
            $table->unsignedInteger('allowed_radius_meter');
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->timestamps();
        });

        Schema::create('class_schedules', function (Blueprint $table) {
            $table->increments('schedule_id');
            $table->unsignedInteger('class_id');
            $table->foreignId('lecturer_id')->constrained('users')->onDelete('restrict');
            $table->string('course_code', 20);
            $table->string('course_name', 150);
            $table->string('class_name', 100);
            $table->string('section', 20);
            $table->string('semester', 20);
            $table->string('academic_session', 20);
            $table->string('day', 20);
            $table->date('schedule_date');
            $table->time('start_time');
            $table->time('end_time');
            $table->string('venue', 100);
            $table->timestamps();

            $table->index('lecturer_id');
            $table->index('schedule_date');
        });

        Schema::create('class_enrollments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('users')->onDelete('restrict');
            $table->unsignedInteger('class_id');
            $table->string('semester', 10);
            $table->enum('status', ['enrolled', 'dropped'])->default('enrolled');
            $table->timestamps();

            $table->index('student_id');
            $table->index('class_id');
        });

        Schema::create('attendance_sessions', function (Blueprint $table) {
            $table->increments('attendance_session_id');
            $table->unsignedInteger('class_id');
            $table->unsignedInteger('schedule_id');
            $table->foreign('schedule_id')->references('schedule_id')->on('class_schedules')->onDelete('restrict');
            $table->foreignId('lecturer_id')->constrained('users')->onDelete('restrict');
            $table->unsignedInteger('campus_boundary_id');
            $table->foreign('campus_boundary_id')->references('campus_boundary_id')->on('campus_boundaries')->onDelete('restrict');
            $table->string('attendance_code', 10)->unique();
            $table->date('session_date');
            $table->dateTime('started_at');
            $table->dateTime('closed_at')->nullable();
            $table->enum('status', ['active', 'closed'])->default('active');
            $table->timestamps();

            $table->index('status');
        });

        Schema::create('class_attendance_submissions', function (Blueprint $table) {
            $table->increments('attendance_submission_id');
            $table->unsignedInteger('attendance_session_id');
            $table->foreign('attendance_session_id')->references('attendance_session_id')->on('attendance_sessions')->onDelete('restrict');
            $table->foreignId('student_id')->constrained('users')->onDelete('restrict');
            $table->string('submitted_code', 10);
            $table->dateTime('submitted_at');
            $table->decimal('gps_latitude', 10, 8);
            $table->decimal('gps_longitude', 11, 8);
            $table->enum('attendance_status', ['present', 'rejected'])->default('present');
            $table->timestamps();

            $table->unique(['attendance_session_id', 'student_id'], 'class_attendance_submissions_session_student_unique');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('class_attendance_submissions');
        Schema::dropIfExists('attendance_sessions');
        Schema::dropIfExists('class_enrollments');
        Schema::dropIfExists('class_schedules');
        Schema::dropIfExists('campus_boundaries');
    }
};
