import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/app_controller.dart';

class PaymentReceiptPage extends StatefulWidget {
  const PaymentReceiptPage({
    super.key,
    required this.controller,
    required this.paymentId,
    this.accessRestored = false,
    this.isNewPayment   = false,
  });
  final AppController controller;
  final int paymentId;
  final bool accessRestored;
  final bool isNewPayment;

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  static const _blue = Color(0xFF1565C0);
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getReceipt(
        token: widget.controller.token!,
        paymentId: widget.paymentId,
      );
      setState(() {
        _receipt = data['receipt'] as Map<String, dynamic>;
        _loading = false;
      });
      if (widget.isNewPayment && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notification sent to your account.'),
            backgroundColor: Color(0xFF1565C0),
            duration: Duration(seconds: 3),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _downloadReceipt() async {
    if (_receipt == null) return;
    try {
      final bytes = await _buildReceiptPdf();
      final txnId = _receipt!['transaction_id'] as String;
      await Printing.sharePdf(bytes: bytes, filename: '$txnId.pdf');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not generate receipt. Please try again.'),
      ));
    }
  }

  Future<void> _printReceipt() async {
    if (_receipt == null) return;
    try {
      await Printing.layoutPdf(onLayout: (_) => _buildReceiptPdf());
    } catch (_) {}
  }

  Future<Uint8List> _buildReceiptPdf() async {
    final r               = _receipt!;
    final student         = r['student']  as Map<String, dynamic>;
    final payment         = r['payment']  as Map<String, dynamic>;
    final fee             = r['fee']      as Map<String, dynamic>;
    final sponsors        = (r['sponsors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sponsorTotal    = (r['sponsor_total']     as num?)?.toDouble() ?? 0.0;
    final feeAmount       = (fee['amount']           as num).toDouble();
    final paidAmount      = (payment['amount']       as num).toDouble();
    final netAfterSponsor = (r['net_after_sponsor']  as num?)?.toDouble() ?? feeAmount;
    final displayTotal    = sponsorTotal > 0 ? netAfterSponsor : paidAmount;

    final pdfBlue   = PdfColor.fromHex('#1565C0');
    final pdfGreen  = PdfColor.fromHex('#16A34A');
    final pdfGrey   = PdfColor.fromHex('#6B7280');
    final pdfLtGrey = PdfColor.fromHex('#E5E7EB');
    final pdfBgGrey = PdfColor.fromHex('#F9FAFB');

    pw.Widget sectionLabel(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(t,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold,
              color: pdfGrey, letterSpacing: 0.8)),
    );

    pw.Widget infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(children: [
        pw.SizedBox(width: 110,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: pdfGrey))),
        pw.Expanded(child: pw.Text(value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
      ]),
    );

    pw.Widget feeRow(String label, double amount,
        {bool bold = false, PdfColor? color}) {
      final neg     = amount < 0;
      final display = '${neg ? '- ' : ''}RM ${amount.abs().toStringAsFixed(2)}';
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(label,
              style: pw.TextStyle(fontSize: 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          pw.Text(display, style: pw.TextStyle(fontSize: 10, color: color,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );
    }

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: pdfBlue,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(children: [
              pw.Text('SA Management System',
                  style: pw.TextStyle(color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold, fontSize: 18)),
              pw.SizedBox(height: 2),
              pw.Text('UMPSA – Official Payment Voucher',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.SizedBox(height: 14),
              pw.Text(r['transaction_id'] as String,
                  style: pw.TextStyle(color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold, fontSize: 16,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: pdfGreen,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                ),
                child: pw.Text('PAYMENT SUCCESSFUL',
                    style: pw.TextStyle(color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
            ]),
          ),

          pw.SizedBox(height: 6),
          pw.Divider(color: pdfLtGrey, thickness: 0.5),

          sectionLabel('STUDENT INFORMATION'),
          infoRow('Name',       student['name']       as String? ?? '-'),
          infoRow('Student ID', student['student_id'] as String? ?? '-'),
          infoRow('Programme',  student['programme']  as String? ?? '-'),
          infoRow('Semester',   '${student['semester'] ?? '-'}'),

          sectionLabel('PAYMENT DETAILS'),
          infoRow('Date',       _formatDate(payment['date'] as String)),
          infoRow('Time',       '${payment['time'] as String} MYT'),
          infoRow('Method',     _methodLabel(payment['method'] as String)),
          infoRow('Invoice No.', r['invoice_no'] as String),

          sectionLabel('FEE ITEMS'),
          feeRow(fee['description'] as String, feeAmount),
          pw.Divider(color: pdfLtGrey, thickness: 0.5),
          feeRow('Subtotal', feeAmount, bold: true),
          ...sponsors.map((s) => feeRow(
              '${s['name']} (${_typeLabel(s['type'] as String)})',
              -(s['amount'] as num).toDouble(),
              color: pdfGreen)),
          pw.Divider(color: pdfLtGrey, thickness: 0.5),
          feeRow('Total Amount Paid', displayTotal, bold: true, color: pdfBlue),

          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: pdfBgGrey,
              border: pw.Border.all(color: pdfLtGrey, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(_amountInWords(displayTotal),
                style: pw.TextStyle(fontSize: 9, color: pdfGrey,
                    fontStyle: pw.FontStyle.italic)),
          ),

          pw.Spacer(),
          pw.Divider(color: pdfLtGrey, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Column(children: [
            pw.Text(
                'This is an official computer-generated receipt. No signature required.',
                style: pw.TextStyle(fontSize: 8, color: pdfGrey)),
            pw.Text('For queries: finance@umpsa.edu.my',
                style: pw.TextStyle(fontSize: 8, color: pdfBlue)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: pdfBgGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                  'UMPSA-RECEIPT-${DateTime.now().year}-${r['transaction_id']}-VERIFIED',
                  style: pw.TextStyle(fontSize: 7, color: pdfGrey)),
            ),
          ])),
        ],
      ),
    ));

    return doc.save();
  }

  String _methodLabel(String m) => switch (m) {
    'online_banking' => 'Online Banking (FPX)',
    'card'           => 'Debit / Credit Card',
    'ewallet'        => 'e-Wallet',
    'cash'           => 'Cash',
    _                => m,
  };

  String _typeLabel(String t) => switch (t) {
    'scholarship' => 'Scholarship',
    'loan'        => 'Loan',
    'bursary'     => 'Bursary',
    'grant'       => 'Grant',
    _             => t,
  };

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _fmt(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '${neg ? '- ' : ''}RM $whole.${parts[1]}';
  }

  String _amountInWords(double amount) {
    final whole = amount.abs().round();
    if (whole == 0) return 'Ringgit Malaysia: Zero Only';
    return 'Ringgit Malaysia: ${_numToWords(whole)} Only';
  }

  static String _numToWords(int n) {
    if (n == 0) return '';
    const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
      'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
      'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
      'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    var words = '';
    if (n >= 1000000) {
      words += '${_numToWords(n ~/ 1000000)} Million ';
      n %= 1000000;
    }
    if (n >= 1000) {
      words += '${_numToWords(n ~/ 1000)} Thousand ';
      n %= 1000;
    }
    if (n >= 100) {
      words += '${ones[n ~/ 100]} Hundred ';
      n %= 100;
    }
    if (n >= 20) {
      words += '${tens[n ~/ 10]} ';
      n %= 10;
    }
    if (n > 0) words += ones[n];
    return words.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Payment Receipt',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    final r         = _receipt!;
    final student   = r['student']  as Map<String, dynamic>;
    final payment   = r['payment']  as Map<String, dynamic>;
    final fee       = r['fee']      as Map<String, dynamic>;
    final sponsors  = (r['sponsors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final sponsorTotal    = (r['sponsor_total']     as num?)?.toDouble() ?? 0.0;
    final feeAmount       = (fee['amount']           as num).toDouble();
    final paidAmount      = (payment['amount']       as num).toDouble();
    final netAfterSponsor = (r['net_after_sponsor']  as num?)?.toDouble() ?? feeAmount;

    final displayTotal = sponsorTotal > 0 ? netAfterSponsor : paidAmount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── GAP 3: Access restored banner ──────────────────────────────────
        if (widget.accessRestored)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              Icon(Icons.lock_open_rounded, color: Colors.white, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text('Your academic access has been restored!',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ]),
          ),

        // ── Receipt card ────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Blue header ───────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(children: [
                  // Logo + institution
                  Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance,
                          color: Color(0xFF1565C0), size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SA Management System',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('UMPSA – Official Payment Voucher',
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Transaction ID
                  Text(r['transaction_id'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 14),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('PAYMENT SUCCESSFUL',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 12,
                              letterSpacing: 0.6)),
                    ]),
                  ),
                ]),
              ),

              // ── Ticket divider ────────────────────────────────────────────
              _TicketDivider(),

              // ── Body ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STUDENT INFORMATION
                    _SectionLabel('STUDENT INFORMATION'),
                    _InfoRow('Name',       student['name']       as String? ?? '-'),
                    _InfoRow('Student ID', student['student_id'] as String? ?? '-'),
                    _InfoRow('Programme',  student['programme']  as String? ?? '-'),
                    _InfoRow('Semester',
                        '${student['semester'] ?? '-'} · Session ${DateTime.now().year - 1}/${DateTime.now().year}'),

                    const SizedBox(height: 18),

                    // PAYMENT DETAILS
                    _SectionLabel('PAYMENT DETAILS'),
                    _InfoRow('Date',       _formatDate(payment['date'] as String)),
                    _InfoRow('Time',       '${payment['time'] as String} MYT'),
                    _InfoRow('Method',     _methodLabel(payment['method'] as String)),
                    _InfoRow('Invoice No.', r['invoice_no'] as String),

                    const SizedBox(height: 18),

                    // FEE ITEMS
                    _SectionLabel('FEE ITEMS'),
                    const SizedBox(height: 4),

                    _AmountRow(
                      label: fee['description'] as String,
                      amount: feeAmount,
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                    ),

                    _AmountRow(
                      label: 'Subtotal',
                      amount: feeAmount,
                      bold: true,
                    ),

                    // Sponsor deductions
                    ...sponsors.map((s) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _AmountRow(
                        label: '${s['name']} (${_typeLabel(s['type'] as String)})',
                        amount: -(s['amount'] as num).toDouble(),
                        green: true,
                      ),
                    )),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                    ),

                    // Total Amount Paid
                    Row(children: [
                      const Expanded(
                        child: Text('Total Amount Paid',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: Color(0xFF111827))),
                      ),
                      Text(_fmt(displayTotal),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: Color(0xFF1565C0))),
                    ]),

                    const SizedBox(height: 10),

                    // Amount in words box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _amountInWords(displayTotal),
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280),
                            fontStyle: FontStyle.italic),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 12),

                    // Footer
                    const Text(
                      'This is an official computer-generated receipt.\nNo signature required. For queries:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('finance@umpsa.edu.my',
                          style: TextStyle(fontSize: 10, color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'UMPSA-RECEIPT-${DateTime.now().year}-${(r['transaction_id'] as String)}-VERIFIED',
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // GAP 7: Download PDF Receipt
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _downloadReceipt(),
            icon: const Icon(Icons.download_outlined, size: 20),
            label: const Text('Download PDF Receipt',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 10),

        // Print
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF374151),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _printReceipt,
            icon: const Icon(Icons.print_outlined, size: 20),
            label: const Text('Print Receipt',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _TicketDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        return SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Row(
                  children: List.generate(
                    (w / 8).floor(),
                    (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven
                            ? const Color(0xFFD1D5DB)
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
              // Left notch circle (uses scaffold bg color to simulate cut-out)
              Positioned(
                left: -14,
                top: 4,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Right notch circle
              Positioned(
                right: -14,
                top: 4,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), letterSpacing: 0.8)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF111827))),
        ),
      ]),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.bold  = false,
    this.green = false,
  });
  final String label;
  final double amount;
  final bool bold, green;

  @override
  Widget build(BuildContext context) {
    final isNeg   = amount < 0;
    final display = isNeg
        ? '- RM ${amount.abs().toStringAsFixed(2)}'
        : 'RM ${amount.toStringAsFixed(2)}';
    final color = green
        ? const Color(0xFF16A34A)
        : const Color(0xFF111827);

    return Row(children: [
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF374151))),
      ),
      Text(display,
          style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color)),
    ]);
  }
}
