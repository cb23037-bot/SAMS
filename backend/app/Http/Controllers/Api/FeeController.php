<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Notification;
use App\Models\Payment;
use App\Models\Restriction;
use App\Models\Sponsor;
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

    // ── GAP 4: all read methods wrapped in try-catch ───────────────────────────

    public function index(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        try {
            $fees = Fee::where('user_id', $request->user()->id)
                ->orderBy('due_date')
                ->get();

            $total  = (float) $fees->sum('amount');
            $paid   = (float) $fees->sum('amount_paid');
            $unpaid = $total - $paid;

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

        if ($fee->user_id !== $request->user()->id) {
            abort(403);
        }

        try {
            $payments = $fee->payments()->orderByDesc('paid_at')->get();

            return response()->json([
                'fee'      => $this->feeArray($fee),
                'payments' => $payments->map(fn($p) => $this->paymentArray($p)),
            ]);
        } catch (\Exception $e) {
            return $this->dbError($e);
        }
    }

    // ── GAP 1, 3, 4, 5: payment processing ───────────────────────────────────

    public function pay(Request $request, Fee $fee): JsonResponse
    {
        $this->requireStudent($request);

        if ($fee->user_id !== $request->user()->id) {
            abort(403);
        }

        if ($fee->status === 'paid') {
            return response()->json(['message' => 'This fee has already been fully paid.'], 422);
        }

        $validated = $request->validate([
            'amount'         => ['required', 'numeric', 'min:1'],
            'payment_method' => ['required', 'string', 'in:online_banking,card,ewallet,cash'],
        ]);

        $remaining = $fee->amount - $fee->amount_paid;
        if ($validated['amount'] > $remaining) {
            return response()->json([
                'message' => "Amount exceeds remaining balance of RM " . number_format($remaining, 2) . ".",
            ], 422);
        }

        try {
            // GAP 5: only the critical writes are inside the transaction.
            // Notifications are non-critical and handled separately below.
            $result = DB::transaction(function () use ($request, $fee, $validated) {
                $payment = Payment::create([
                    'fee_id'         => $fee->id,
                    'user_id'        => $request->user()->id,
                    'amount'         => $validated['amount'],
                    'payment_method' => $validated['payment_method'],
                    'reference_no'   => strtoupper(Str::random(12)),
                    'paid_at'        => now(),
                ]);

                $fee->recalculate();
                $freshFee = $fee->fresh();

                $accessRestored = false;

                // GAP 3: auto-lift restriction when all fees settled
                if ($freshFee->status === 'paid') {
                    $hasRemainingUnpaid = Fee::where('user_id', $request->user()->id)
                        ->whereIn('status', ['unpaid', 'partial'])
                        ->exists();

                    if (!$hasRemainingUnpaid) {
                        $lifted = Restriction::where('user_id', $request->user()->id)
                            ->where('status', 'active')
                            ->update([
                                'status'      => 'lifted',
                                'lifted_date' => now()->toDateString(),
                                'lifted_by'   => $request->user()->id,
                            ]);

                        if ($lifted > 0) {
                            $accessRestored = true;
                        }
                    }
                }

                return [
                    'payment'         => $payment,
                    'fee'             => $freshFee,
                    'access_restored' => $accessRestored,
                ];
            });
        } catch (\Exception $e) {
            // GAP 5: payment write failure → 503
            Log::error('Payment processing failed: ' . $e->getMessage());
            return response()->json([
                'error'   => true,
                'message' => 'Payment service is currently unavailable. Please try again later.',
                'code'    => 'GATEWAY_UNAVAILABLE',
            ], 503);
        }

        // GAP 1: payment success notification (non-critical, never blocks response).
        try {
            Notification::create([
                'user_id' => $request->user()->id,
                'title'   => 'Payment Successful',
                'message' => 'Your payment of RM ' . number_format($validated['amount'], 2)
                    . ' for ' . $fee->semester . ' has been received. Transaction ID: '
                    . $result['payment']->reference_no,
                'type' => 'payment_success',
            ]);

            if ($result['access_restored']) {
                Notification::create([
                    'user_id' => $request->user()->id,
                    'title'   => 'Academic Access Restored',
                    'message' => 'Your academic access has been restored. Thank you for settling your tuition fees for '
                        . $fee->semester . '.',
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
            $restriction = Restriction::where('user_id', $request->user()->id)
                ->where('status', 'active')
                ->latest()
                ->first();

            $semesterStart = DB::table('settings')
                ->where('key', 'semester_start_date')->value('value');
            $currentWeek = null;
            if ($semesterStart) {
                $day         = \Carbon\Carbon::parse($semesterStart)->startOfDay()->diffInDays(\Carbon\Carbon::today()) + 1;
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
            $payments = Payment::with('fee')
                ->where('user_id', $request->user()->id)
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
            $charges = Fee::where('user_id', $userId)->get()->map(fn($f) => [
                'id'          => 'fee-' . $f->id,
                'type'        => 'charge',
                'description' => $f->description,
                'amount'      => -(float) $f->amount,
                'reference'   => 'TXN-' . $f->created_at->format('Y') . '-' . str_pad($f->id, 4, '0', STR_PAD_LEFT),
                'date'        => $f->created_at->toDateString(),
            ]);

            $payments = Payment::with('fee')->where('user_id', $userId)->get()->map(fn($p) => [
                'id'          => 'pay-' . $p->id,
                'type'        => 'payment',
                'description' => $p->fee->description . ' Payment',
                'amount'      => (float) $p->amount,
                'reference'   => $p->reference_no,
                'date'        => $p->paid_at->toDateString(),
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

        if ($payment->user_id !== $request->user()->id) {
            abort(403);
        }

        try {
            $fee  = $payment->fee;
            $user = $request->user();

            $sponsors = Sponsor::where('user_id', $user->id)
                ->where('status', 'active')
                ->where('amount', '>', 0)
                ->get();

            $sponsorTotal = $sponsors->sum('amount');

            return response()->json([
                'receipt' => [
                    'transaction_id' => $payment->reference_no,
                    'invoice_no'     => 'INV-' . $payment->paid_at->format('Y') . '-' . str_pad($payment->id, 5, '0', STR_PAD_LEFT),
                    'student' => [
                        'name'       => $user->name,
                        'student_id' => $user->student_id,
                        'programme'  => $user->course,
                        'semester'   => $user->current_semester,
                    ],
                    'payment' => [
                        'date'   => $payment->paid_at->toDateString(),
                        'time'   => $payment->paid_at->format('H:i'),
                        'method' => $payment->payment_method,
                        'amount' => (float) $payment->amount,
                    ],
                    'fee' => [
                        'description' => $fee->description,
                        'amount'      => (float) $fee->amount,
                        'semester'    => $fee->semester,
                    ],
                    'sponsors' => $sponsors->map(fn($s) => [
                        'name'   => $s->name,
                        'amount' => (float) $s->amount,
                        'type'   => $s->type,
                    ]),
                    'sponsor_total'     => (float) $sponsorTotal,
                    'net_after_sponsor' => (float) $fee->amount - (float) $sponsorTotal,
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
            'amount'      => $fee->amount,
            'amount_paid' => $fee->amount_paid,
            'balance'     => $fee->amount - $fee->amount_paid,
            'due_date'    => $fee->due_date->toDateString(),
            'status'      => $fee->status,
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
            'paid_at'        => $payment->paid_at->toISOString(),
        ];
    }
}
