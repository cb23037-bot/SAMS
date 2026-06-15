<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // fees: add description column needed by Module 3 (e.g. "Tuition Fee", "Accommodation Fee")
        Schema::table('fees', function (Blueprint $table) {
            $table->string('description')->nullable()->after('semester');
        });

        // payments: add reference_no and paid_at needed for receipt display
        Schema::table('payments', function (Blueprint $table) {
            $table->string('reference_no')->nullable()->unique()->after('payment_method');
            $table->timestamp('paid_at')->nullable()->after('reference_no');
        });

        // restrictions: add lifted_by for audit trail
        Schema::table('restrictions', function (Blueprint $table) {
            $table->unsignedBigInteger('lifted_by')->nullable()->after('lifted_date');
            $table->foreign('lifted_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('fees', function (Blueprint $table) {
            $table->dropColumn('description');
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->dropUnique(['reference_no']);
            $table->dropColumn(['reference_no', 'paid_at']);
        });

        Schema::table('restrictions', function (Blueprint $table) {
            $table->dropForeign(['lifted_by']);
            $table->dropColumn('lifted_by');
        });
    }
};
