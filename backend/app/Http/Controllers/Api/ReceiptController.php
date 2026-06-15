<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Sponsor;
use Illuminate\Http\Request;

class ReceiptController extends Controller
{
    /**
     * Generate and download a PDF receipt for a payment.
     *
     * Requires: composer require barryvdh/laravel-dompdf
     * Falls back to a print-ready HTML page if DomPDF is not installed.
     *
     * GET /api/receipts/{payment}/download
     */
    public function download(Request $request, Payment $payment): mixed
    {
        $user = $request->user();

        // Students can only access their own receipts; treasury can access all
        if ($user->role === 'student' && $payment->user_id !== $user->id) {
            abort(403);
        }

        $fee      = $payment->fee;
        $student  = $payment->user;

        $sponsors = Sponsor::where('user_id', $student->id)
            ->where('status', 'active')
            ->where('amount', '>', 0)
            ->get();

        $sponsorTotal = $sponsors->sum('amount');

        $netAfterSponsor = (float) $fee->amount - (float) $sponsorTotal;
        $displayTotal    = $sponsorTotal > 0 ? $netAfterSponsor : (float) $payment->amount;

        $data = [
            'transaction_id'  => $payment->reference_no,
            'invoice_no'      => 'INV-' . $payment->paid_at->format('Y') . '-' . str_pad($payment->id, 5, '0', STR_PAD_LEFT),
            'paid_at'         => $payment->paid_at,
            'method'          => $payment->payment_method,
            'amount'          => (float) $payment->amount,
            'student' => [
                'name'       => $student->name,
                'student_id' => $student->student_id,
                'programme'  => $student->course,
                'semester'   => $student->current_semester,
            ],
            'fee' => [
                'description' => $fee->description,
                'amount'      => (float) $fee->amount,
                'semester'    => $fee->semester,
            ],
            'sponsors'          => $sponsors,
            'sponsor_total'     => (float) $sponsorTotal,
            'net_after_sponsor' => $netAfterSponsor,
            'display_total'     => $displayTotal,
            'amount_in_words'   => $this->numToWords((int) abs(round($displayTotal))),
        ];

        $filename = "UMPSA-Receipt-{$data['transaction_id']}.pdf";

        // Use DomPDF if available, otherwise return print-ready HTML
        if (class_exists(\Barryvdh\DomPDF\Facade\Pdf::class)) {
            $pdf = \Barryvdh\DomPDF\Facade\Pdf::loadView('receipts.payment_receipt', $data);
            return $pdf->download($filename);
        }

        // Fallback: return HTML with print styles (browser → Save as PDF)
        return response()
            ->view('receipts.payment_receipt', $data)
            ->header('Content-Type', 'text/html; charset=UTF-8');
    }

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
