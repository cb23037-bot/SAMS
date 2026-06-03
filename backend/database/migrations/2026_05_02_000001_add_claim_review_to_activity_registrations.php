<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE activity_registrations MODIFY COLUMN claim_status ENUM('not_claimed','pending','claimed','rejected') NOT NULL DEFAULT 'not_claimed'");

        Schema::table('activity_registrations', function (Blueprint $table) {
            $table->text('remarks')->nullable()->after('proof_path');
            $table->text('rejection_reason')->nullable()->after('remarks');
        });
    }

    public function down(): void
    {
        Schema::table('activity_registrations', function (Blueprint $table) {
            $table->dropColumn(['remarks', 'rejection_reason']);
        });

        DB::statement("ALTER TABLE activity_registrations MODIFY COLUMN claim_status ENUM('not_claimed','pending','claimed') NOT NULL DEFAULT 'not_claimed'");
    }
};
