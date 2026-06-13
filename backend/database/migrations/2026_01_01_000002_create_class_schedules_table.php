<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// SAMS-PACK-402 — ClassSchedule Table
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('class_schedules', function (Blueprint $table) {
            $table->increments('schedule_id');
            $table->unsignedInteger('class_id')->comment('Reference to class record from another module');
            $table->foreignId('lecturer_id')->constrained('users')->restrictOnDelete();
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
    }

    public function down(): void
    {
        Schema::dropIfExists('class_schedules');
    }
};
