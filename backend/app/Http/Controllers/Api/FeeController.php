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
    protected function requireStudent(Request $request): void
    {
        if ($request->user()->role !== 'student') {
            abort(403, 'Unauthorized.');
        }
    }

    private function dbError(\Exception $e): JsonResponse
    {
        Log::error('FeeController DB error: ' . $e->getMessage());
        return response()->json([
            'error'   => true,
            'message' => 'Failed to retrieve data. Please try again later.',
            'code'    => 'DB_ERROR',
        ], 500);
    }

    private function getStudent(Request $request): Student
    {
        return Student::where('user_id', $request->user()->id)->firstOrFail();
    }

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
