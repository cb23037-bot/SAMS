<?php

// NOTE: This controller is not registered in routes/api.php.
// Payment processing is handled by FeeController::pay().
// Kept for reference only.

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Fee;
use App\Models\Payment;
use App\Models\Receipt;
use App\Models\Student;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'fee_id'         => 'required|integer|exists:fees,id',
            'amount'         => 'required|numeric|min:0.01',
            'payment_method' => 'required|string',
        ]);

        $student = Student::where('user_id', $request->user()->id)->firstOrFail();
        $fee     = Fee::where('student_id', $student->id)->findOrFail($validated['fee_id']);

        if ($validated['amount'] > $fee->outstanding_amount) {
            return response()->json(['message' => 'Amount exceeds outstanding balance.'], 422);
        }

        $payment = Payment::create([
            'fee_id'         => $fee->id,
            'amount'         => $validated['amount'],
            'payment_method' => $validated['payment_method'],
            'status'         => 'Pending',
        ]);

        $success         = $validated['payment_method'] !== 'fail_test';
        $payment->status = $success ? 'Success' : 'Failed';
        $payment->save();

        $gatewayRef = $success ? 'GW-' . strtoupper(Str::random(12)) : null;

        Transaction::create([
            'payment_id'        => $payment->id,
            'gateway_reference' => $gatewayRef,
            'gateway_status'    => $success ? 'success' : 'failed',
            'payload'           => json_encode([
                'method' => $validated['payment_method'],
                'amount' => $validated['amount'],
            ]),
        ]);

        if ($success) {
            $newOutstanding              = max(0, $fee->outstanding_amount - $validated['amount']);
            $fee->outstanding_amount     = $newOutstanding;
            $fee->status                 = $newOutstanding <= 0 ? 'Paid' : 'Partial';
            $fee->save();

            $receiptNumber = 'RCP-' . str_pad($payment->id, 5, '0', STR_PAD_LEFT);
            $receiptHash   = hash('sha256', $receiptNumber . config('app.key'));

            Receipt::create([
                'payment_id'     => $payment->id,
                'receipt_number' => $receiptNumber,
                'file_path'      => 'receipts/' . $receiptNumber . '.pdf',
                'receipt_hash'   => $receiptHash,
            ]);

            return response()->json([
                'success'        => true,
                'payment'        => $payment->fresh(['receipt', 'transaction']),
                'receipt_number' => $receiptNumber,
                'transaction_id' => $gatewayRef,
            ]);
        }

        return response()->json([
            'success' => false,
            'payment' => $payment,
            'message' => 'Payment gateway declined the transaction.',
        ], 402);
    }

    public function history(Request $request)
    {
        $student = Student::where('user_id', $request->user()->id)->firstOrFail();

        $payments = Payment::with(['transaction', 'receipt', 'fee'])
            ->whereHas('fee', fn($q) => $q->where('student_id', $student->id))
            ->where('status', 'Success')
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['payments' => $payments]);
    }

    public function webhook(Request $request)
    {
        $gatewayRef    = $request->input('reference');
        $gatewayStatus = $request->input('status');

        if (!$gatewayRef || !$gatewayStatus) {
            return response()->json(['message' => 'Invalid payload.'], 400);
        }

        $transaction = Transaction::where('gateway_reference', $gatewayRef)->first();

        if (!$transaction) {
            return response()->json(['message' => 'Transaction not found.'], 404);
        }

        $transaction->gateway_status = $gatewayStatus;
        $transaction->save();

        return response()->json(['message' => 'Webhook processed.']);
    }
}
