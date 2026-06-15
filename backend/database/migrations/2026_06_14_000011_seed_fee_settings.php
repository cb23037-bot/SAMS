<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (!DB::table('settings')->where('key', 'semester_start_date')->exists()) {
            DB::table('settings')->insert(['key' => 'semester_start_date', 'value' => '2026-01-06', 'updated_at' => now()]);
        }
        if (!DB::table('settings')->where('key', 'week5_auto_enforce')->exists()) {
            DB::table('settings')->insert(['key' => 'week5_auto_enforce', 'value' => 'true', 'updated_at' => now()]);
        }
    }

    public function down(): void
    {
        DB::table('settings')->whereIn('key', ['semester_start_date', 'week5_auto_enforce'])->delete();
    }
};
