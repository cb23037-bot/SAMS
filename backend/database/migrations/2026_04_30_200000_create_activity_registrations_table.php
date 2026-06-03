<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('activity_registrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('activity_slot_id')->constrained('activity_slots')->onDelete('cascade');
            $table->enum('claim_status', ['not_claimed', 'pending', 'claimed'])->default('not_claimed');
            $table->timestamps();

            $table->unique(['user_id', 'activity_slot_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('activity_registrations');
    }
};
