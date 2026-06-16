<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Notification;
use App\Models\Payment;
use App\Models\Restriction;
use App\Models\Student;
use App\Models\Transaction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class TreasuryController extends Controller
{
    // Aborts with 403 if the authenticated user does not have the 'treasury' role.
    protected function requireTreasury(Request $request): void
    {
        if ($request->user()->role !== 'treasury') {
            abort(403, 'Unauthorized.');
        }
    }

    // Logs the exception and returns a standard 500 JSON error response.
    // Accepts an optional $code string to select a more specific error message
    // (e.g. 'RESTRICTION_ERROR' returns a restriction-specific message).
    private function dbError(\Exception $e, string $code = 'DB_ERROR'): JsonResponse
    {
        Log::error("TreasuryController [{$code}]: " . $e->getMessage());
        $message = $code === 'RESTRICTION_ERROR'
            ? 'Failed to update access status. Please retry.'
            : 'Failed to retrieve data. Please try again later.';
        return response()->json([
            'error'   => true,
            'message' => $message,
            'code'    => $code,
        ], 500);
    }

    // ── Dashboard / Stats ─────────────────────────────────────────────────────

    // GET /api/treasury/dashboard
    // Returns high-level financial statistics for the treasury dashboard:
    // total fees, total paid, total unpaid, number of unpaid records,
    // number of active restrictions, current semester week, and the 5 most
    // recent successful payments. Only accessible to users with role 'treasury'.
    public function dashboard(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        try {
            $totalFees   = (float) Fee::sum('total_amount');
            $totalPaid   = (float) Fee::sum('total_amount') - (float) Fee::sum('outstanding_amount');
            $unpaidCount = Fee::whereNotIn('status', ['Paid'])->count();
            $restricted  = Restriction::where('status', 'Active')->count();

            $semesterStart = DB::table('settings')->where('key', 'semester_start_date')->value('value');
            $currentWeek   = null;
            if ($semesterStart) {
                $day         = Carbon::parse($semesterStart)->startOfDay()->diffInDays(Carbon::today()) + 1;
                $currentWeek = (int) ceil($day / 7);
            }

            $recentPayments = Payment::with(['fee.student.user'])
                ->where('status', 'Success')
                ->orderByDesc('paid_at')
                ->limit(5)
                ->get();

            return response()->json([
                'stats' => [
                    'total_fees'   => $totalFees,
                    'total_paid'   => $totalPaid,
                    'total_unpaid' => $totalFees - $totalPaid,
                    'unpaid_count' => $unpaidCount,
                    'restricted'   => $restricted,
                    'current_week' => $currentWeek,
                ],
                'recent_payments' => $recentPayments->map(fn($p) => [
                    'id'              => $p->id,
                    'amount'          => $p->amount,
                    'payment_method'  => $p->payment_method,
                    'reference_no'    => $p->reference_no,
                    'paid_at'         => ($p->paid_at ?? $p->created_at)->toISOString(),
                    'student_name'    => optional($p->fee->student->user)->name ?? 'Unknown',
                    'student_id'      => optional($p->fee->student)->matric_number ?? '',
                    'fee_description' => $p->fee->description,
                ]),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/treasury/stats
    // Returns a simplified statistics snapshot: student counts, paid/unpaid counts,
    // total money collected, total outstanding, and the 5 most recent transactions.
    // Used for the treasury stats widget on the dashboard.
    public function stats(): JsonResponse
    {
        $totalStudents    = Student::count();
        $paidCount        = Fee::where('status', 'Paid')->count();
        $unpaidCount      = Fee::whereIn('status', ['Unpaid', 'Partial'])->count();
        $totalCollected   = (float) Payment::where('status', 'Success')->sum('amount');
        $totalOutstanding = (float) Fee::sum('outstanding_amount');

        $recentTransactions = Payment::with(['fee.student.user'])
            ->where('status', 'Success')
            ->orderByDesc('created_at')
            ->take(5)
            ->get()
            ->map(fn($p) => [
                'id'             => $p->id,
                'student_name'   => optional($p->fee->student->user)->name ?? 'Unknown',
                'amount'         => $p->amount,
                'payment_method' => $p->payment_method,
                'created_at'     => $p->created_at,
            ]);

        return response()->json([
            'total_students'      => $totalStudents,
            'total_paid_count'    => $paidCount,
            'total_unpaid_count'  => $unpaidCount,
            'total_collected'     => $totalCollected,
            'total_outstanding'   => $totalOutstanding,
            'recent_transactions' => $recentTransactions,
        ]);
    }

    // ── Fee Records ───────────────────────────────────────────────────────────

    // GET /api/treasury/fees
    // Returns all student fee records, with optional 'search' (student name or
    // matric number) and 'status' (Paid/Unpaid/Partial) query parameters.
    // Results are sorted so unpaid fees appear first, then partial, then paid,
    // and within each group by due date ascending.
    public function feeRecords(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        try {
            $query = Fee::with(['student.user'])
                ->when($request->filled('search'), function ($q) use ($request) {
                    $search = $request->search;
                    $q->where(function ($inner) use ($search) {
                        $inner->whereHas('student.user', fn($sq) => $sq->where('name', 'like', "%$search%"))
                              ->orWhereHas('student', fn($sq) => $sq->where('matric_number', 'like', "%$search%"));
                    });
                })
                ->when($request->filled('status'), fn($q) => $q->where('status', ucfirst($request->status)))
                ->orderByRaw("FIELD(status,'Unpaid','Partial','Paid')")
                ->orderBy('due_date');

            $fees = $query->get();

            return response()->json([
                'fees' => $fees->map(fn($f) => $this->feeRow($f)),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/treasury/fees/{fee}
    // Returns the full detail of a single fee record, including the student's
    // profile, any active financial restrictions on that student, and the full
    // payment history for this fee. Only accessible to treasury users.
    public function feeDetail(Request $request, Fee $fee): JsonResponse
    {
        $this->requireTreasury($request);

        try {
            $fee->load(['student.user', 'student.restrictions', 'payments.receipt', 'payments.transaction']);
            $s = $fee->student;

            return response()->json([
                'fee'      => [
                    'id'                 => $fee->id,
                    'semester'           => $fee->semester,
                    'description'        => $fee->description,
                    'total_amount'       => $fee->total_amount,
                    'outstanding_amount' => $fee->outstanding_amount,
                    'amount_paid'        => $fee->amount_paid,
                    'due_date'           => $fee->due_date->toDateString(),
                    'status'             => strtolower($fee->status),
                    'student'            => [
                        'id'            => $s->id,
                        'user_id'       => $s->user->id ?? null,
                        'matric_number' => $s->matric_number ?? '',
                        'program_code'  => $s->program_code ?? '',
                        'user'          => ['name' => $s->user->name ?? 'Unknown'],
                        'restrictions'  => $s->restrictions->map(fn($r) => [
                            'id'               => $r->id,
                            'restriction_type' => $r->restriction_type,
                            'status'           => $r->status,
                            'applied_date'     => $r->applied_date->toDateString(),
                        ]),
                    ],
                ],
                'payments' => $fee->payments->map(fn($p) => [
                    'id'             => $p->id,
                    'amount'         => $p->amount,
                    'payment_method' => $p->payment_method,
                    'reference_no'   => $p->reference_no,
                    'paid_at'        => ($p->paid_at ?? $p->created_at)->toISOString(),
                ]),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // POST /api/treasury/fees/{fee}/pay
    // Records a manual payment against the given fee on behalf of the treasury.
    // Accepts 'amount' (required, numeric >= 0) and 'remarks' (optional string).
    // Creates a Payment record with method 'Manual', a random reference number,
    // and a Transaction record to log any remarks. Recalculates the fee status
    // (Unpaid/Partial/Paid) after posting. Returns the updated fee row.
    public function updateRecord(Request $request, Fee $fee): JsonResponse
    {
        $this->requireTreasury($request);

        $validated = $request->validate([
            'amount'  => 'required|numeric|min:0',
            'remarks' => 'nullable|string|max:500',
        ]);

        try {
            $payment = Payment::create([
                'fee_id'         => $fee->id,
                'amount'         => $validated['amount'],
                'payment_method' => 'Manual',
                'status'         => 'Success',
                'reference_no'   => 'MANUAL-' . strtoupper(Str::random(8)),
                'paid_at'        => now(),
            ]);

            Transaction::create([
                'payment_id'        => $payment->id,
                'gateway_reference' => $payment->reference_no,
                'gateway_status'    => 'success',
                'payload'           => json_encode(['remarks' => $validated['remarks'] ?? '']),
            ]);

            $fee->recalculate();

            return response()->json(['fee' => $this->feeRow($fee->fresh(['student.user']))]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // ── Unpaid Monitor ────────────────────────────────────────────────────────

    // GET /api/treasury/unpaid
    // Returns a grouped list of students who have at least one Unpaid or Partial
    // fee. Each entry aggregates all outstanding fees for that student into a
    // single summary: total balance, total amount, earliest due date, semester
    // list, and whether the student is currently under an active restriction.
    // Uses a pre-fetched set of restricted student IDs for efficient O(1) lookup.
    public function unpaid(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        try {
            $fees = Fee::with(['student.user'])
                ->whereIn('status', ['Unpaid', 'Partial'])
                ->orderBy('due_date')
                ->get();

            // Pre-fetch restricted student IDs in one query for O(1) lookup
            $studentIds    = $fees->pluck('student_id')->unique()->values()->all();
            $restrictedIds = Restriction::whereIn('student_id', $studentIds)
                ->where('status', 'Active')
                ->pluck('student_id')
                ->flip()
                ->all();

            $students = $fees->groupBy('student_id')->map(function ($studentFees) use ($restrictedIds) {
                $student      = $studentFees->first()->student;
                $user         = $student->user;
                $totalBalance = (float) $studentFees->sum('outstanding_amount');
                $totalAmount  = (float) $studentFees->sum('total_amount');
                $totalPaid    = $totalAmount - $totalBalance;
                $earliestDue  = $studentFees->min('due_date');
                $hasPartial   = $studentFees->contains('status', 'Partial');
                $semesters    = $studentFees->pluck('semester')->unique()->values()->all();

                return [
                    'student_id'    => $student->id,
                    'user_id'       => $user->id,
                    'student_name'  => $user->name,
                    'matric_number' => $student->matric_number ?? '',
                    'fee_count'     => $studentFees->count(),
                    'semesters'     => $semesters,
                    'total_balance' => $totalBalance,
                    'total_amount'  => $totalAmount,
                    'total_paid'    => $totalPaid,
                    'earliest_due'  => $earliestDue?->toDateString(),
                    'status'        => strtolower($hasPartial ? 'Partial' : 'Unpaid'),
                    'is_restricted' => isset($restrictedIds[$student->id]),
                ];
            })->values();

            return response()->json(['fees' => $students]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // ── Restriction Management ────────────────────────────────────────────────

    // POST /api/treasury/restrict/{userId}
    // Places an active 'financial_bar' restriction on the student identified by
    // $userId. Returns 409 if the student is already restricted.
    // On success: creates a Restriction record and sends a 'restriction'
    // notification to the student with the outstanding balance and semester.
    // The notification is fire-and-forget — a failure is logged but does not
    // roll back the restriction.
    public function restrict(Request $request, int $userId): JsonResponse
    {
        $this->requireTreasury($request);

        $user    = User::where('id', $userId)->where('role', 'student')->firstOrFail();
        $student = Student::where('user_id', $user->id)->firstOrFail();

        $already = Restriction::where('student_id', $student->id)
            ->where('restriction_type', 'financial_bar')
            ->where('status', 'Active')
            ->exists();

        if ($already) {
            return response()->json([
                'message' => 'Student is already restricted.',
                'code'    => 'ALREADY_RESTRICTED',
            ], 409);
        }

        try {
            $outstandingFee = Fee::where('student_id', $student->id)
                ->whereIn('status', ['Unpaid', 'Partial'])
                ->orderBy('due_date')
                ->first();

            $r = Restriction::create([
                'student_id'       => $student->id,
                'restriction_type' => 'financial_bar',
                'status'           => 'Active',
                'applied_date'     => now()->toDateString(),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e, 'RESTRICTION_ERROR');
        }

        try {
            $semester = $outstandingFee?->semester ?? 'current semester';
            $balance  = $outstandingFee
                ? number_format($outstandingFee->outstanding_amount, 2)
                : '0.00';
            Notification::create([
                'user_id' => $user->id,
                'title'   => 'Academic Access Restricted',
                'message' => "Your academic access has been restricted due to unpaid tuition fees for {$semester}. "
                    . "Outstanding balance: RM{$balance}. Please make payment immediately to restore access.",
                'type'    => 'restriction',
            ]);
        } catch (\Exception $e) {
            Log::warning("restrict: notification failed for user {$user->id}: " . $e->getMessage());
        }

        return response()->json(['restriction' => $this->restrictionArray($r)], 201);
    }

    // POST /api/treasury/lift/{userId}
    // Lifts all active 'financial_bar' restrictions on the student identified by
    // $userId. Sets status to 'Lifted', records the lifted date and the ID of
    // the treasury user performing the action. Returns 404 if no active
    // restriction exists. On success, sends an 'access_restored' notification
    // to the student. Notification failure is logged but does not undo the lift.
    public function lift(Request $request, int $userId): JsonResponse
    {
        $this->requireTreasury($request);

        $user    = User::where('id', $userId)->where('role', 'student')->firstOrFail();
        $student = Student::where('user_id', $user->id)->firstOrFail();

        try {
            $updated = Restriction::where('student_id', $student->id)
                ->where('restriction_type', 'financial_bar')
                ->where('status', 'Active')
                ->update([
                    'status'      => 'Lifted',
                    'lifted_date' => now()->toDateString(),
                    'lifted_by'   => $request->user()->id,
                ]);
        } catch (\Exception $e) {
            return $this->dbError($e, 'RESTRICTION_ERROR');
        }

        if ($updated === 0) {
            return response()->json(['message' => 'No active restriction found.'], 404);
        }

        try {
            Notification::create([
                'user_id' => $user->id,
                'title'   => 'Academic Access Restored',
                'message' => 'Your academic access restriction has been lifted by the Finance Office.',
                'type'    => 'access_restored',
            ]);
        } catch (\Exception $e) {
            Log::warning("lift: notification failed for user {$user->id}: " . $e->getMessage());
        }

        return response()->json(['message' => 'Restriction lifted.']);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    // Converts a Fee model into a flat summary array for treasury list views.
    // Includes student name, matric number, and user ID so the frontend can
    // link to the student's profile without a separate lookup.
    private function feeRow(Fee $fee): array
    {
        $user = $fee->student->user ?? null;
        return [
            'id'             => $fee->id,
            'student_name'   => $user?->name ?? 'Unknown',
            'matric_number'  => $fee->student?->matric_number ?? '',
            'student_db_id'  => $fee->student_id,
            'user_id'        => $user?->id,
            'semester'       => $fee->semester,
            'description'    => $fee->description,
            'amount'         => $fee->total_amount,
            'amount_paid'    => $fee->amount_paid,
            'balance'        => $fee->outstanding_amount,
            'due_date'       => $fee->due_date->toDateString(),
            'status'         => strtolower($fee->status),
        ];
    }

    // Converts a Restriction model into a small array for API responses.
    // Returns just the fields the frontend needs to display or act on a restriction.
    private function restrictionArray(Restriction $r): array
    {
        return [
            'id'               => $r->id,
            'restriction_type' => $r->restriction_type,
            'status'           => strtolower($r->status),
            'applied_date'     => $r->applied_date->toDateString(),
        ];
    }
}
