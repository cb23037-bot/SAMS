<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('course')->nullable()->after('student_id');
            $table->string('phone_number')->nullable()->after('course');
            $table->string('current_semester')->nullable()->after('phone_number');
            $table->string('personal_advisor')->nullable()->after('current_semester');
            $table->text('address')->nullable()->after('personal_advisor');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['course', 'phone_number', 'current_semester', 'personal_advisor', 'address']);
        });
    }
};
