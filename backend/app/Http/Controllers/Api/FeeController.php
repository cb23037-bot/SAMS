<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class FeeController extends Controller
{
    protected function requireStudent(Request $request): void
    {
        if ($request->user()->role !== 'student') {
            abort(403, 'Unauthorized.');
        }
    }

    public function index(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $fees = Fee::where('user_id', $request->user()->id)
            ->orderBy('due_date')
            ->get();

        $total    = $fees->sum('amount');
        $paid     = $fees->sum('amount_paid');
        $unpaid   = $total - $paid;

        return response()->json([
            'summary' => [
                'total'    => $total,
                'paid'     => $paid,
                'unpaid'   => $unpaid,
                'count'    => $fees->count(),
            ],
            'fees' => $fees->map(fn($f) => $this->feeArray($f)),
        ]);
    }

    public function show(Request $request, Fee $fee): JsonResponse
    {
        $this->requireStudent($request);

        if ($fee->user_id !== $request->user()->id) {
            abort(403);
        }

        $payments = $fee->payments()->orderByDesc('paid_at')->get();

        return response()->json([
            'fee'      => $this->feeArray($fee),
            'payments' => $payments->map(fn($p) => $this->paymentArray($p)),
        ]);
    }

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
            return response()->json(['message' => "Amount exceeds remaining balance of RM " . number_format($remaining, 2) . "."], 422);
        }

        $payment = Payment::create([
            'fee_id'         => $fee->id,
            'user_id'        => $request->user()->id,
            'amount'         => $validated['amount'],
            'payment_method' => $validated['payment_method'],
            'reference_no'   => strtoupper(Str::random(12)),
            'paid_at'        => now(),
        ]);

        $fee->recalculate();

        return response()->json([
            'payment' => $this->paymentArray($payment),
            'fee'     => $this->feeArray($fee->fresh()),
        ], 201);
    }

    public function history(Request $request): JsonResponse
    {
        $this->requireStudent($request);

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
