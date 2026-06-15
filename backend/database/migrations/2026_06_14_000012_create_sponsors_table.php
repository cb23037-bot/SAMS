<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('sponsors')) {
            Schema::create('sponsors', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->string('name');
                $table->enum('type', ['scholarship', 'loan', 'bursary', 'grant']);
                $table->string('coverage')->nullable();
                $table->decimal('amount', 12, 2)->default(0);
                $table->enum('status', ['active', 'inactive', 'not_applied']);
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sponsors');
    }
};
