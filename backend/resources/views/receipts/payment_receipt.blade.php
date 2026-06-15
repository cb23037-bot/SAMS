<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Payment Receipt – {{ $transaction_id }}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 12px; color: #111827; background: #f0f4f8; }
  .page { max-width: 600px; margin: 24px auto; background: #fff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,.1); }
  .header { background: linear-gradient(135deg,#1565C0,#1976D2); color:#fff; padding:28px 24px 24px; text-align:center; }
  .logo-row { display:flex; align-items:center; justify-content:center; gap:14px; margin-bottom:18px; }
  .logo-box { width:52px; height:52px; background:#fff; border-radius:10px; display:flex; align-items:center; justify-content:center; }
  .inst-name { font-size:16px; font-weight:700; text-align:left; }
  .inst-sub  { font-size:11px; opacity:.75; text-align:left; margin-top:2px; }
  .txn-id    { font-size:18px; font-weight:800; letter-spacing:.5px; margin-bottom:14px; }
  .badge { display:inline-block; background:#16A34A; color:#fff; font-size:12px; font-weight:800; padding:6px 18px; border-radius:24px; }
  .divider-row { display:flex; align-items:center; background:#fff; }
  .notch { width:20px; height:20px; border-radius:50%; background:#f0f4f8; flex-shrink:0; }
  .dashes { flex:1; border-top:1px dashed #d1d5db; margin:0 4px; }
  .body { padding:8px 24px 28px; }
  .section-label { font-size:10px; font-weight:800; color:#6b7280; letter-spacing:.8px; text-transform:uppercase; margin:18px 0 10px; }
  .info-row { display:flex; padding:5px 0; }
  .info-label { width:120px; color:#6b7280; flex-shrink:0; }
  .info-value { font-weight:600; }
  .fee-row { display:flex; justify-content:space-between; padding:4px 0; color:#374151; }
  .bold  { font-weight:700; }
  .green { color:#16A34A; }
  .blue  { font-size:15px; font-weight:800; color:#1565C0; }
  hr { border:none; border-top:1px solid #e5e7eb; margin:10px 0; }
  .words-box { background:#f9fafb; border:1px solid #e5e7eb; border-radius:8px; padding:10px 14px; font-size:11px; color:#6b7280; font-style:italic; margin-top:8px; }
  .footer { border-top:1px solid #f3f4f6; margin-top:20px; padding-top:12px; text-align:center; font-size:10px; color:#9ca3af; line-height:1.6; }
  .footer a { color:#1565C0; font-weight:600; }
  .verify-box { display:inline-block; background:#f3f4f6; border-radius:6px; padding:4px 10px; font-size:9px; color:#9ca3af; margin-top:8px; }
  @media print { body{background:#fff;} .page{box-shadow:none;margin:0;border-radius:0;} }
</style>
</head>
<body>
<div class="page">

  <div class="header">
    <div class="logo-row">
      <div class="logo-box">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="#1565C0">
          <path d="M12 2L3 7v10l9 5 9-5V7l-9-5zm0 2.18L19 8.5v7l-7 3.82L5 15.5v-7l7-3.82z"/>
        </svg>
      </div>
      <div>
        <div class="inst-name">SA Management System</div>
        <div class="inst-sub">UMPSA – Official Payment Voucher</div>
      </div>
    </div>
    <div class="txn-id">{{ $transaction_id }}</div>
    <span class="badge">&#10003; PAYMENT SUCCESSFUL</span>
  </div>

  <div class="divider-row">
    <div class="notch"></div>
    <div class="dashes"></div>
    <div class="notch"></div>
  </div>

  <div class="body">

    <div class="section-label">Student Information</div>
    <div class="info-row"><span class="info-label">Name</span><span class="info-value">{{ $student['name'] }}</span></div>
    <div class="info-row"><span class="info-label">Student ID</span><span class="info-value">{{ $student['student_id'] }}</span></div>
    <div class="info-row"><span class="info-label">Programme</span><span class="info-value">{{ $student['programme'] }}</span></div>
    <div class="info-row"><span class="info-label">Semester</span><span class="info-value">{{ $student['semester'] }} &middot; Session {{ $paid_at->year - 1 }}/{{ $paid_at->year }}</span></div>

    <div class="section-label">Payment Details</div>
    <div class="info-row"><span class="info-label">Date</span><span class="info-value">{{ $paid_at->format('d M Y') }}</span></div>
    <div class="info-row"><span class="info-label">Time</span><span class="info-value">{{ $paid_at->format('H:i') }} MYT</span></div>
    <div class="info-row"><span class="info-label">Method</span><span class="info-value">
      @switch($method)
        @case('online_banking') Online Banking (FPX) @break
        @case('card') Debit / Credit Card @break
        @case('ewallet') e-Wallet @break
        @case('cash') Cash @break
        @default {{ $method }}
      @endswitch
    </span></div>
    <div class="info-row"><span class="info-label">Invoice No.</span><span class="info-value">{{ $invoice_no }}</span></div>

    <div class="section-label">Fee Items</div>
    <div class="fee-row"><span>{{ $fee['description'] }}</span><span>RM {{ number_format($fee['amount'], 2) }}</span></div>
    <hr>
    <div class="fee-row bold"><span>Subtotal</span><span>RM {{ number_format($fee['amount'], 2) }}</span></div>

    @foreach($sponsors as $s)
    <div class="fee-row green"><span>{{ $s->name }} ({{ ucfirst($s->type) }})</span><span>- RM {{ number_format($s->amount, 2) }}</span></div>
    @endforeach

    <hr>
    <div class="fee-row blue">
      <span>Total Amount Paid</span>
      <span>{{ $display_total < 0 ? '- ' : '' }}RM {{ number_format(abs($display_total), 2) }}</span>
    </div>

    <div class="words-box">{{ $amount_in_words }}</div>

    <div class="footer">
      This is an official computer-generated receipt. No signature required.<br>
      For queries: <a href="mailto:finance@umpsa.edu.my">finance@umpsa.edu.my</a><br>
      <span class="verify-box">UMPSA-RECEIPT-{{ $paid_at->year }}-{{ $transaction_id }}-VERIFIED</span>
    </div>

  </div>
</div>
</body>
</html>
