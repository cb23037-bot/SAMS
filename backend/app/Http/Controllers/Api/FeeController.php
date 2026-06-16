<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Notification;
use App\Models\Payment;
use App\Models\Restriction;
use App\Models\Sponsor;
use App\Models\Student;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class FeeController extends Controller
{
    // Aborts with 403 if the authenticated user is not a student.
    protected function requireStudent(Request $request): void
    {
        if ($request->user()->role !== 'student') {
            abort(403, 'Unauthorized.');
        }
    }

    // Logs the exception and returns a standard 500 JSON error response.
    private function dbError(\Exception $e): JsonResponse
    {
        Log::error('FeeController DB error: ' . $e->getMessage());
        return response()->json([
            'error'   => true,
            'message' => 'Failed to retrieve data. Please try again later.',
            'code'    => 'DB_ERROR',
        ], 500);
    }

    // Looks up the Student record linked to the authenticated user.
    // Throws 404 if no student profile exists for this user.
    private function getStudent(Request $request): Student
    {
        return Student::where('user_id', $request->user()->id)->firstOrFail();
    }

    // GET /api/fees
    // Returns a summary (total, paid, unpaid, count) and a list of all
    // fee records for the authenticated student, ordered by due date.
    public function index(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student = $this->getStudent($request);
            $fees    = Fee::where('student_id', $student->id)
                ->orderBy('due_date')
                ->get();

            $total  = (float) $fees->sum('total_amount');
            $unpaid = (float) $fees->sum('outstanding_amount');
            $paid   = $total - $unpaid;

            return response()->json([
                'summary' => [
                    'total'  => $total,
                    'paid'   => $paid,
                    'unpaid' => $unpaid,
                    'count'  => $fees->count(),
                ],
                'fees' => $fees->map(fn($f) => $this->feeArray($f)),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/fees/{fee}
    // Returns the full details of a single fee and its payment history.
    // Returns 403 if the fee does not belong to the authenticated student.
    public function show(Request $request, Fee $fee): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student = $this->getStudent($request);
            if ($fee->student_id !== $student->id) abort(403);

            $payments = $fee->payments()->orderByDesc('paid_at')->get();

            return response()->json([
                'fee'      => $this->feeArray($fee),
                'payments' => $payments->map(fn($p) => $this->paymentArray($p)),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // POST /api/fees/{fee}/pay
    // Processes a payment for the given fee. Accepts 'amount' and 'payment_method'
    // in the request body. The amount must be > 0 and must not exceed the outstanding balance.
    // On success: creates a Payment record, recalculates the fee status (Unpaid/Partial/Paid),
    // and automatically lifts any active financial restriction if all fees are now paid.
    // Sends a 'payment_success' notification (and optionally 'access_restored') to the student.
    // Returns 422 if the fee is already paid or the amount is invalid.
    // Returns 503 if the payment transaction itself fails.
    public function pay(Request $request, Fee $fee): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student = $this->getStudent($request);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
        if ($fee->student_id !== $student->id) abort(403);

        if ($fee->status === 'Paid') {
            return response()->json(['message' => 'This fee has already been fully paid.'], 422);
        }

        $validated = $request->validate([
            'amount'         => ['required', 'numeric', 'min:1'],
            'payment_method' => ['required', 'string', 'in:online_banking,card,ewallet,cash'],
        ]);

        if ($validated['amount'] > $fee->outstanding_amount) {
            return response()->json([
                'message' => 'Amount exceeds remaining balance of RM '
                    . number_format($fee->outstanding_amount, 2) . '.',
            ], 422);
        }

        try {
            $result = DB::transaction(function () use ($request, $fee, $validated, $student) {
                $payment = Payment::create([
                    'fee_id'         => $fee->id,
                    'amount'         => $validated['amount'],
                    'payment_method' => $validated['payment_method'],
                    'status'         => 'Success',
                    'reference_no'   => strtoupper(Str::random(12)),
                    'paid_at'        => now(),
                ]);

                $fee->recalculate();
                $freshFee = $fee->fresh();

                $accessRestored = false;

                if ($freshFee->status === 'Paid') {
                    $hasRemainingUnpaid = Fee::where('student_id', $student->id)
                        ->whereIn('status', ['Unpaid', 'Partial'])
                        ->exists();

                    if (!$hasRemainingUnpaid) {
                        $lifted = Restriction::where('student_id', $student->id)
                            ->where('status', 'Active')
                            ->update([
                                'status'      => 'Lifted',
                                'lifted_date' => now()->toDateString(),
                                'lifted_by'   => $request->user()->id,
                            ]);

                        if ($lifted > 0) $accessRestored = true;
                    }
                }

                return [
                    'payment'         => $payment,
                    'fee'             => $freshFee,
                    'access_restored' => $accessRestored,
                ];
            });
        } catch (\Exception $e) {
            Log::error('Payment processing failed: ' . $e->getMessage());
            return response()->json([
                'error'   => true,
                'message' => 'Payment service is currently unavailable. Please try again later.',
                'code'    => 'GATEWAY_UNAVAILABLE',
            ], 503);
        }

        try {
            $user = $request->user();
            Notification::create([
                'user_id' => $user->id,
                'title'   => 'Payment Successful',
                'message' => 'Your payment of RM ' . number_format($validated['amount'], 2)
                    . ' for ' . $fee->semester . ' has been received. Transaction ID: '
                    . $result['payment']->reference_no,
                'type' => 'payment_success',
            ]);

            if ($result['access_restored']) {
                Notification::create([
                    'user_id' => $user->id,
                    'title'   => 'Academic Access Restored',
                    'message' => 'Your academic access has been restored. Thank you for settling '
                        . 'your fees for ' . $fee->semester . '.',
                    'type' => 'access_restored',
                ]);
            }
        } catch (\Exception $e) {
            Log::warning('pay: notification failed for user ' . $request->user()->id . ': ' . $e->getMessage());
        }

        return response()->json([
            'payment'         => $this->paymentArray($result['payment']),
            'fee'             => $this->feeArray($result['fee']),
            'access_restored' => $result['access_restored'],
        ], 201);
    }

    // GET /api/student/restriction-status
    // Returns whether the student currently has an active financial restriction,
    // along with the restriction type, the date it was applied, and the current
    // semester week number (calculated from the semester_start_date setting).
    public function restrictionStatus(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student     = $this->getStudent($request);
            $restriction = Restriction::where('student_id', $student->id)
                ->where('status', 'Active')
                ->latest()
                ->first();

            $semesterStart = DB::table('settings')
                ->where('key', 'semester_start_date')->value('value');
            $currentWeek = null;
            if ($semesterStart) {
                $day         = \Carbon\Carbon::parse($semesterStart)->startOfDay()
                    ->diffInDays(\Carbon\Carbon::today()) + 1;
                $currentWeek = (int) ceil($day / 7);
            }

            return response()->json([
                'restricted'       => $restriction !== null,
                'restriction_type' => $restriction?->restriction_type,
                'applied_date'     => $restriction?->applied_date?->toDateString(),
                'current_week'     => $currentWeek,
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/payments
    // Returns all successful payments made by the authenticated student,
    // ordered newest-first. Each entry includes the fee description and semester.
    public function history(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student  = $this->getStudent($request);
            $payments = Payment::with('fee')
                ->whereHas('fee', fn($q) => $q->where('student_id', $student->id))
                ->where('status', 'Success')
                ->orderByDesc('paid_at')
                ->get();

            return response()->json([
                'payments' => $payments->map(fn($p) => array_merge(
                    $this->paymentArray($p),
                    ['fee_description' => $p->fee->description, 'fee_semester' => $p->fee->semester]
                )),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/student/sponsors
    // Returns all sponsor records (scholarships, loans, bursaries, grants)
    // linked to the authenticated student, sorted so active sponsors appear first.
    public function sponsors(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $sponsors = Sponsor::where('user_id', $request->user()->id)
                ->orderByRaw("CASE status WHEN 'active' THEN 0 WHEN 'inactive' THEN 1 ELSE 2 END")
                ->get();

            return response()->json([
                'sponsors' => $sponsors->map(fn($s) => [
                    'id'       => $s->id,
                    'name'     => $s->name,
                    'type'     => $s->type,
                    'coverage' => $s->coverage,
                    'amount'   => (float) $s->amount,
                    'status'   => $s->status,
                ]),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/student/ledger
    // Returns a combined, date-sorted transaction history for the student,
    // including fee charges (negative), successful payments (positive),
    // and active sponsor disbursements (positive). Used on the History tab
    // of the fee dashboard to give the student a full financial picture.
    public function ledger(Request $request): JsonResponse
    {
        $this->requireStudent($request);
        $userId = $request->user()->id;

        try {
            $student = $this->getStudent($request);

            $charges = Fee::where('student_id', $student->id)->get()->map(fn($f) => [
                'id'          => 'fee-' . $f->id,
                'type'        => 'charge',
                'description' => $f->description,
                'amount'      => -(float) $f->total_amount,
                'reference'   => 'TXN-' . $f->created_at->format('Y') . '-' . str_pad($f->id, 4, '0', STR_PAD_LEFT),
                'date'        => $f->created_at->toDateString(),
            ]);

            $payments = Payment::with('fee')
                ->whereHas('fee', fn($q) => $q->where('student_id', $student->id))
                ->where('status', 'Success')
                ->get()
                ->map(fn($p) => [
                    'id'          => 'pay-' . $p->id,
                    'type'        => 'payment',
                    'description' => ($p->fee->description ?? $p->fee->semester) . ' Payment',
                    'amount'      => (float) $p->amount,
                    'reference'   => $p->reference_no,
                    'date'        => ($p->paid_at ?? $p->created_at)->toDateString(),
                ]);

            $disbursements = Sponsor::where('user_id', $userId)
                ->where('status', 'active')
                ->where('amount', '>', 0)
                ->get()
                ->map(fn($s) => [
                    'id'          => 'spon-' . $s->id,
                    'type'        => 'scholarship',
                    'description' => $s->name . ' Disbursement',
                    'amount'      => (float) $s->amount,
                    'reference'   => 'SCH-' . str_pad($s->id, 4, '0', STR_PAD_LEFT),
                    'date'        => $s->created_at->toDateString(),
                ]);

            $all = collect([...$charges, ...$payments, ...$disbursements])
                ->sortByDesc('date')
                ->values();

            return response()->json(['transactions' => $all]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // GET /api/payments/{payment}/receipt
    // Returns structured receipt data for a specific payment as JSON.
    // Used by the Flutter frontend to render the in-app receipt screen.
    // Returns 403 if the payment belongs to a different student.
    // Includes student info, payment details, fee breakdown, and any active
    // sponsor deductions so the app can display the net amount paid.
    public function receipt(Request $request, Payment $payment): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $student = $this->getStudent($request);
            if ($payment->fee->student_id !== $student->id) abort(403);

            $fee  = $payment->fee;
            $user = $request->user();

            $sponsors = Sponsor::where('user_id', $user->id)
                ->where('status', 'active')
                ->where('amount', '>', 0)
                ->get();

            $sponsorTotal = (float) $sponsors->sum('amount');

            return response()->json([
                'receipt' => [
                    'transaction_id' => $payment->reference_no,
                    'invoice_no'     => 'INV-' . ($payment->paid_at ?? $payment->created_at)->format('Y')
                        . '-' . str_pad($payment->id, 5, '0', STR_PAD_LEFT),
                    'student' => [
                        'name'       => $user->name,
                        'student_id' => $user->student_id,
                        'programme'  => $user->course,
                        'semester'   => $user->current_semester,
                    ],
                    'payment' => [
                        'date'   => ($payment->paid_at ?? $payment->created_at)->toDateString(),
                        'time'   => ($payment->paid_at ?? $payment->created_at)->format('H:i'),
                        'method' => $payment->payment_method,
                        'amount' => (float) $payment->amount,
                    ],
                    'fee' => [
                        'description' => $fee->description,
                        'amount'      => (float) $fee->total_amount,
                        'semester'    => $fee->semester,
                    ],
                    'sponsors' => $sponsors->map(fn($s) => [
                        'name'   => $s->name,
                        'amount' => (float) $s->amount,
                        'type'   => $s->type,
                    ]),
                    'sponsor_total'     => $sponsorTotal,
                    'net_after_sponsor' => (float) $fee->total_amount - $sponsorTotal,
                ],
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // Converts a Fee model into a flat array safe to send as JSON.
    // Normalises the status field to lowercase so the Flutter app
    // can compare it with simple string equality (e.g. 'paid', 'unpaid').
    private function feeArray(Fee $fee): array
    {
        return [
            'id'          => $fee->id,
            'semester'    => $fee->semester,
            'description' => $fee->description,
            'amount'      => $fee->total_amount,
            'amount_paid' => $fee->amount_paid,        // uses getAmountPaidAttribute accessor
            'balance'     => $fee->outstanding_amount,
            'due_date'    => $fee->due_date->toDateString(),
            'status'      => strtolower($fee->status), // normalize Titlecase → lowercase for Flutter
        ];
    }

    // Converts a Payment model into a flat array safe to send as JSON.
    // Falls back to created_at if paid_at is null (e.g. manually recorded payments).
    private function paymentArray(Payment $payment): array
    {
        return [
            'id'             => $payment->id,
            'fee_id'         => $payment->fee_id,
            'amount'         => $payment->amount,
            'payment_method' => $payment->payment_method,
            'reference_no'   => $payment->reference_no,
            'paid_at'        => ($payment->paid_at ?? $payment->created_at)->toISOString(),
        ];
    }
}
