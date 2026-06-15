<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AccessController extends Controller
{
    private static function currentAccess(): string
    {
        return DB::table('settings')->where('key', 'student_access')->value('value') ?? 'open';
    }

    private static function semesterStartDate(): string
    {
        return DB::table('settings')->where('key', 'semester_start_date')->value('value') ?? '2026-06-01';
    }

    public static function accessState(): array
    {
        $manualStatus = self::currentAccess();
        $semesterStart = CarbonImmutable::parse(self::semesterStartDate())->startOfDay();
        $week5Cutoff = $semesterStart->addWeeks(4);
        $now = CarbonImmutable::now()->startOfDay();
        $week5Closed = $now->greaterThanOrEqualTo($week5Cutoff);

        $effectiveStatus = 'open';
        $reason = 'open';

        if ($manualStatus === 'closed') {
            $effectiveStatus = 'closed';
            $reason = 'manual_closed';
        } elseif ($week5Closed) {
            $effectiveStatus = 'closed';
            $reason = 'week_5_closed';
        }

        return [
            'student_access'      => $effectiveStatus,
            'manual_access'       => $manualStatus,
            'semester_start_date' => $semesterStart->toDateString(),
            'week_5_cutoff'       => $week5Cutoff->toDateString(),
            'reason'              => $reason,
        ];
    }

    // GET /api/adab/access  (adab only)
    public function show(Request $request): JsonResponse
    {
        $this->requireAdab($request);
        return response()->json(self::accessState());
    }

    // PUT /api/adab/access  { status: 'open'|'closed' }  (adab only)
    public function update(Request $request): JsonResponse
    {
        $this->requireAdab($request);

        $request->validate(['status' => ['required', 'in:open,closed']]);

        DB::table('settings')->updateOrInsert(
            ['key' => 'student_access'],
            ['value' => $request->status, 'updated_at' => now()]
        );

        return response()->json(self::accessState());
    }

    // GET /api/student/access  (any authenticated user — students use this)
    public function studentCheck(): JsonResponse
    {
        return response()->json(self::accessState());
    }
}
