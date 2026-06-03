<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendance_submissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('activity_slot_id')->constrained('activity_slots')->onDelete('cascade');
            $table->string('attendance_code_submitted', 8);
            $table->string('photo_path');
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('address')->nullable();
            $table->string('receipt_id')->unique();
            $table->string('receipt_hash');
            $table->timestamps();
            // No unique(user_id, activity_slot_id) — re-attendance is intentional
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_submissions');
    }
};
