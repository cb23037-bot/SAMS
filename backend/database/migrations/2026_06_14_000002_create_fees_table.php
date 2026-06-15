<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fees', function (Blueprint $table) {
            $table->id();
            $table->foreignId('student_id')->constrained('students')->cascadeOnDelete();
            $table->string('semester', 50);
            $table->decimal('total_amount', 10, 2);
            $table->decimal('outstanding_amount', 10, 2);
            $table->date('due_date');
            $table->enum('status', ['Paid', 'Unpaid', 'Partial'])->default('Unpaid');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fees');
    }
};
