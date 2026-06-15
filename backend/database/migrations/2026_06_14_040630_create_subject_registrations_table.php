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
        Schema::create('subject_registrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('subject_id')->constrained()->onDelete('cascade');
            
            // Storing the specific sections selected
            $table->string('lecture_section');
            $table->string('lecture_instructor')->nullable();
            $table->string('lecture_schedule')->nullable();
            
            $table->string('lab_section')->nullable();
            $table->string('lab_instructor')->nullable();
            $table->string('lab_schedule')->nullable();
            
            // New status column for PA approval workflow
            $table->string('status')->default('pending'); // Options: pending, approved, rejected
            
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('subject_registrations');
    }
};