<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('settings')->updateOrInsert(
            ['key' => 'semester_start_date'],
            ['value' => '2026-06-01', 'updated_at' => now()],
        );
    }

    public function down(): void
    {
        DB::table('settings')->where('key', 'semester_start_date')->delete();
    }
};
