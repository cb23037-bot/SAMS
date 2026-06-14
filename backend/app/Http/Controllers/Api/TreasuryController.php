<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Payment;
use App\Models\Restriction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TreasuryController extends Controller
{
    protected function requireTreasury(Request $request): void
    {
        if ($request->user()->role !== 'treasury') {
            abort(403, 'Unauthorized.');
        }
    }

    // ── Dashboard ─────────────────────────────────────────────────────────────

    public function dashboard(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $totalFees    = Fee::sum('amount');
        $totalPaid    = Fee::sum('amount_paid');
        $unpaidCount  = Fee::where('status', '!=', 'paid')->count();
        $restricted   = Restriction::where('status', 'active')->count();

        $semesterStart  = DB::table('settings')->where('key', 'semester_start_date')->value('value');
        $currentWeek    = null;
        if ($semesterStart) {
            $day         = Carbon::parse($semesterStart)->startOfDay()->diffInDays(Carbon::today()) + 1;
            $currentWeek = (int) ceil($day / 7);
        }

        $recentPayments = Payment::with(['user', 'fee'])
            ->orderByDesc('paid_at')
            ->limit(5)
            ->get();

        return response()->json([
            'stats' => [
                'total_fees'    => $totalFees,
                'total_paid'    => $totalPaid,
                'total_unpaid'  => $totalFees - $totalPaid,
                'unpaid_count'  => $unpaidCount,
                'restricted'    => $restricted,
                'current_week'  => $currentWeek,
            ],
            'recent_payments' => $recentPayments->map(fn($p) => [
                'id'              => $p->id,
                'amount'          => $p->amount,
                'payment_method'  => $p->payment_method,
                'reference_no'    => $p->reference_no,
                'paid_at'         => $p->paid_at->toISOString(),
                'student_name'    => $p->user->name,
                'student_id'      => $p->user->student_id,
                'fee_description' => $p->fee->description,
            ]),
        ]);
    }

    // ── Fee Records ───────────────────────────────────────────────────────────

    public function feeRecords(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $fees = Fee::with('user')
            ->orderByRaw("FIELD(status,'unpaid','partial','paid')")
            ->orderBy('due_date')
            ->get();

        return response()->json([
            'fees' => $fees->map(fn($f) => $this->feeRow($f)),
        ]);
    }

    public function feeDetail(Request $request, Fee $fee): JsonResponse
    {
        $this->requireTreasury($request);

        $payments = $fee->payments()->orderByDesc('paid_at')->get();

        return response()->json([
            'fee'      => $this->feeRow($fee),
            'payments' => $payments->map(fn($p) => [
                'id'             => $p->id,
                'amount'         => $p->amount,
                'payment_method' => $p->payment_method,
                'reference_no'   => $p->reference_no,
                'paid_at'        => $p->paid_at->toISOString(),
            ]),
        ]);
    }

    // ── Unpaid Monitor ────────────────────────────────────────────────────────

    public function unpaid(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $fees = Fee::with(['user', 'user.restrictions' => fn($q) => $q->where('status', 'active')])
            ->whereIn('status', ['unpaid', 'partial'])
            ->orderBy('due_date')
            ->get();

        return response()->json([
            'fees' => $fees->map(fn($f) => array_merge($this->feeRow($f), [
                'is_restricted' => $f->user->restrictions->isNotEmpty(),
            ])),
        ]);
    }

    // ── Restriction Management ────────────────────────────────────────────────

    public function restrict(Request $request, int $userId): JsonResponse
    {
        $this->requireTreasury($request);

        $student = User::where('id', $userId)->where('role', 'student')->firstOrFail();

        $already = Restriction::where('user_id', $student->id)
            ->where('restriction_type', 'financial_bar')
            ->where('status', 'active')
            ->exists();

        if ($already) {
            return response()->json(['message' => 'Student is already restricted.'], 422);
        }

        $r = Restriction::create([
            'user_id'          => $student->id,
            'restriction_type' => 'financial_bar',
            'status'           => 'active',
            'applied_date'     => now()->toDateString(),
        ]);

        return response()->json(['restriction' => $this->restrictionArray($r)], 201);
    }

    public function lift(Request $request, int $userId): JsonResponse
    {
        $this->requireTreasury($request);

        $student = User::where('id', $userId)->where('role', 'student')->firstOrFail();

        $updated = Restriction::where('user_id', $student->id)
            ->where('restriction_type', 'financial_bar')
            ->where('status', 'active')
            ->update([
                'status'      => 'lifted',
                'lifted_date' => now()->toDateString(),
                'lifted_by'   => $request->user()->id,
            ]);

        if ($updated === 0) {
            return response()->json(['message' => 'No active restriction found.'], 404);
        }

        return response()->json(['message' => 'Restriction lifted.']);
    }

    // ── Settings ──────────────────────────────────────────────────────────────

    public function updateSettings(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $validated = $request->validate([
            'week5_auto_enforce'  => ['sometimes', 'boolean'],
            'semester_start_date' => ['sometimes', 'date'],
        ]);

        foreach ($validated as $key => $value) {
            DB::table('settings')->updateOrInsert(
                ['key' => $key],
                ['value' => is_bool($value) ? ($value ? 'true' : 'false') : $value, 'updated_at' => now()]
            );
        }

        return response()->json(['message' => 'Settings updated.']);
    }

    public function getSettings(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $rows = DB::table('settings')
            ->whereIn('key', ['semester_start_date', 'week5_auto_enforce'])
            ->pluck('value', 'key');

        return response()->json([
            'semester_start_date' => $rows['semester_start_date'] ?? null,
            'week5_auto_enforce'  => ($rows['week5_auto_enforce'] ?? 'true') === 'true',
        ]);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function feeRow(Fee $fee): array
    {
        return [
            'id'           => $fee->id,
            'student_name' => $fee->user->name,
            'student_id'   => $fee->user->student_id,
            'user_id'      => $fee->user_id,
            'semester'     => $fee->semester,
            'description'  => $fee->description,
            'amount'       => $fee->amount,
            'amount_paid'  => $fee->amount_paid,
            'balance'      => $fee->amount - $fee->amount_paid,
            'due_date'     => $fee->due_date->toDateString(),
            'status'       => $fee->status,
        ];
    }

    private function restrictionArray(Restriction $r): array
    {
        return [
            'id'               => $r->id,
            'restriction_type' => $r->restriction_type,
            'status'           => $r->status,
            'applied_date'     => $r->applied_date->toDateString(),
        ];
    }
}
