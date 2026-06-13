<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->string('password');
            $table->enum('role', [
                'student', 'lecturer', 'treasury_staff',
                'pusat_adab_staff', 'faculty_registrar'
            ]);
            $table->string('student_id', 50)->nullable()->unique()
                  ->comment('Matric number, students only');
            $table->string('course')->nullable()
                  ->comment('Programme name, students only');
            $table->string('phone_number', 20)->nullable();
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->rememberToken();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};