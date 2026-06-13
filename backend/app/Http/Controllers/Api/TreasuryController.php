<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TreasuryController extends Controller
{
    protected function requireTreasury(Request $request): void
    {
        if ($request->user()->role !== 'treasury') {
            abort(403, 'Unauthorized.');
        }
    }

    public function dashboard(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $totalFees     = Fee::sum('amount');
        $totalPaid     = Fee::sum('amount_paid');
        $totalUnpaid   = $totalFees - $totalPaid;
        $unpaidCount   = Fee::where('status', '!=', 'paid')->count();
        $studentCount  = User::where('role', 'student')->count();

        $recentPayments = Payment::with(['user', 'fee'])
            ->orderByDesc('paid_at')
            ->limit(5)
            ->get();

        return response()->json([
            'stats' => [
                'total_fees'    => $totalFees,
                'total_paid'    => $totalPaid,
                'total_unpaid'  => $totalUnpaid,
                'unpaid_count'  => $unpaidCount,
                'student_count' => $studentCount,
            ],
            'recent_payments' => $recentPayments->map(fn($p) => [
                'id'             => $p->id,
                'amount'         => $p->amount,
                'payment_method' => $p->payment_method,
                'reference_no'   => $p->reference_no,
                'paid_at'        => $p->paid_at->toISOString(),
                'student_name'   => $p->user->name,
                'student_id'     => $p->user->student_id,
                'fee_description'=> $p->fee->description,
            ]),
        ]);
    }

    public function feeRecords(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $fees = Fee::with('user')
            ->orderBy('status')
            ->orderBy('due_date')
            ->get();

        return response()->json([
            'fees' => $fees->map(fn($f) => [
                'id'            => $f->id,
                'student_name'  => $f->user->name,
                'student_id'    => $f->user->student_id,
                'semester'      => $f->semester,
                'description'   => $f->description,
                'amount'        => $f->amount,
                'amount_paid'   => $f->amount_paid,
                'balance'       => $f->amount - $f->amount_paid,
                'due_date'      => $f->due_date->toDateString(),
                'status'        => $f->status,
            ]),
        ]);
    }

    public function feeDetail(Request $request, Fee $fee): JsonResponse
    {
        $this->requireTreasury($request);

        $payments = $fee->payments()->with('user')->orderByDesc('paid_at')->get();

        return response()->json([
            'fee' => [
                'id'            => $fee->id,
                'student_name'  => $fee->user->name,
                'student_id'    => $fee->user->student_id,
                'semester'      => $fee->semester,
                'description'   => $fee->description,
                'amount'        => $fee->amount,
                'amount_paid'   => $fee->amount_paid,
                'balance'       => $fee->amount - $fee->amount_paid,
                'due_date'      => $fee->due_date->toDateString(),
                'status'        => $fee->status,
            ],
            'payments' => $payments->map(fn($p) => [
                'id'             => $p->id,
                'amount'         => $p->amount,
                'payment_method' => $p->payment_method,
                'reference_no'   => $p->reference_no,
                'paid_at'        => $p->paid_at->toISOString(),
            ]),
        ]);
    }

    public function unpaid(Request $request): JsonResponse
    {
        $this->requireTreasury($request);

        $fees = Fee::with('user')
            ->where('status', '!=', 'paid')
            ->orderBy('due_date')
            ->get();

        return response()->json([
            'fees' => $fees->map(fn($f) => [
                'id'           => $f->id,
                'student_name' => $f->user->name,
                'student_id'   => $f->user->student_id,
                'description'  => $f->description,
                'semester'     => $f->semester,
                'amount'       => $f->amount,
                'amount_paid'  => $f->amount_paid,
                'balance'      => $f->amount - $f->amount_paid,
                'due_date'     => $f->due_date->toDateString(),
                'status'       => $f->status,
            ]),
        ]);
    }
}
