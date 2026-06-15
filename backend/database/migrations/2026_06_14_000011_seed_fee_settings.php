<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('settings')->upsert([
            ['key' => 'semester_start_date', 'value' => '2026-01-06', 'updated_at' => now()],
            ['key' => 'week5_auto_enforce',  'value' => 'true',       'updated_at' => now()],
        ], ['key'], ['value', 'updated_at']);
    }

    public function down(): void
    {
        DB::table('settings')->whereIn('key', ['semester_start_date', 'week5_auto_enforce'])->delete();
    }
};
