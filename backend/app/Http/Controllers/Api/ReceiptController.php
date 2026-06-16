<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Receipt;
use App\Models\Sponsor;
use App\Models\Student;
use Illuminate\Http\Request;

class ReceiptController extends Controller
{
    /**
     * GET /api/receipts/{payment}/download
     * Generates a PDF (or HTML fallback) receipt for a payment.
     *
     * Students may only download their own receipts; treasury can download any.
     */
    public function download(Request $request, Payment $payment): mixed
    {
        $user = $request->user();

        if ($user->role === 'student') {
            $student = Student::where('user_id', $user->id)->firstOrFail();
            if ($payment->fee->student_id !== $student->id) {
                abort(403);
            }
        }

        $fee         = $payment->fee;
        $studentUser = $fee->student->user;

        $sponsors = Sponsor::where('user_id', $studentUser->id)
            ->where('status', 'active')
            ->where('amount', '>', 0)
            ->get();

        $sponsorTotal    = (float) $sponsors->sum('amount');
        $netAfterSponsor = (float) $fee->total_amount - $sponsorTotal;
        $displayTotal    = $sponsorTotal > 0 ? $netAfterSponsor : (float) $payment->amount;
        $paidAt          = $payment->paid_at ?? $payment->created_at;

        $data = [
            'transaction_id'  => $payment->reference_no,
            'invoice_no'      => 'INV-' . $paidAt->format('Y') . '-' . str_pad($payment->id, 5, '0', STR_PAD_LEFT),
            'paid_at'         => $paidAt,
            'method'          => $payment->payment_method,
            'amount'          => (float) $payment->amount,
            'student'         => [
                'name'       => $studentUser->name,
                'student_id' => $studentUser->student_id,
                'programme'  => $studentUser->course,
                'semester'   => $studentUser->current_semester,
            ],
            'fee'             => [
                'description' => $fee->description,
                'amount'      => (float) $fee->total_amount,
                'semester'    => $fee->semester,
            ],
            'sponsors'          => $sponsors,
            'sponsor_total'     => $sponsorTotal,
            'net_after_sponsor' => $netAfterSponsor,
            'display_total'     => $displayTotal,
            'amount_in_words'   => $this->numToWords((int) abs(round($displayTotal))),
        ];

        $filename = "UMPSA-Receipt-{$data['transaction_id']}.pdf";

        if (class_exists(\Barryvdh\DomPDF\Facade\Pdf::class)) {
            $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('receipts.payment_receipt', $data);
            return $pdf->download($filename);
        }

        return response()
            ->view('receipts.payment_receipt', $data)
            ->header('Content-Type', 'text/html; charset=UTF-8');
    }

    /**
     * GET /api/receipts/{receiptId}/json
     * Returns receipt metadata as JSON (for mobile clients that render their own UI).
     */
    public function show(Request $request, int $receiptId): \Illuminate\Http\JsonResponse
    {
        $receipt = Receipt::with(['payment.fee.student'])->findOrFail($receiptId);
        $user    = $request->user();

        if ($user->role === 'student') {
            $student = Student::where('user_id', $user->id)->firstOrFail();
            if ($receipt->payment->fee->student_id !== $student->id) {
                return response()->json(['message' => 'Forbidden.'], 403);
            }
        }

        return response()->json([
            'receipt'        => $receipt,
            'receipt_number' => $receipt->receipt_number,
            'file_path'      => $receipt->file_path,
            'receipt_hash'   => $receipt->receipt_hash,
        ]);
    }

    // Converts an integer (e.g. 1250) to its English word representation
    // (e.g. "One Thousand Two Hundred Fifty"). Used to write the receipt
    // amount in words, as required on official payment receipts.
    // Handles values up to the millions. Returns 'Zero' for n = 0.
    private function numToWords(int $n): string
    {
        if ($n === 0) return 'Zero';
        $ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten',
                 'Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
        $tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
        $w = '';
        if ($n >= 1000000) { $w .= $this->numToWords(intdiv($n, 1000000)) . ' Million '; $n %= 1000000; }
        if ($n >= 1000)    { $w .= $this->numToWords(intdiv($n, 1000))    . ' Thousand '; $n %= 1000; }
        if ($n >= 100)     { $w .= $ones[intdiv($n, 100)] . ' Hundred '; $n %= 100; }
        if ($n >= 20)      { $w .= $tens[intdiv($n, 10)] . ' '; $n %= 10; }
        if ($n > 0)        { $w .= $ones[$n]; }
        return trim($w);
    }
}
