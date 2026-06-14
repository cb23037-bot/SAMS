import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'payment_receipt_page.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  static const _blue = Color(0xFF1565C0);
  bool _loading = true;
  String? _error;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getPaymentHistory(
        token: widget.controller.token!,
      );
      setState(() {
        _payments = data['payments'] as List<dynamic>? ?? [];
        _loading  = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double get _totalPaid => _payments.fold(
    0.0,
    (sum, p) => sum + ((p as Map<String, dynamic>)['amount'] as num).toDouble(),
  );

  // Group payments by "MONTH YEAR" label, preserving API order (desc)
  List<MapEntry<String, List<Map<String, dynamic>>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    const months = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
    ];
    for (final p in _payments.cast<Map<String, dynamic>>()) {
      final dt  = DateTime.tryParse(p['paid_at'] as String? ?? '');
      final key = dt != null ? '${months[dt.month - 1]} ${dt.year}' : 'UNKNOWN';
      map.putIfAbsent(key, () => []).add(p);
    }
    return map.entries.toList();
  }

  String _methodLabel(String m) => switch (m) {
    'online_banking' => 'Online Banking (FPX)',
    'card'           => 'Debit / Credit Card',
    'ewallet'        => 'e-Wallet',
    'cash'           => 'Cash',
    _                => m,
  };

  String _formatDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h   = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$min';
    } catch (_) { return iso; }
  }

  String _fmtAmount(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RM $whole.${parts[1]}';
  }

  void _openReceipt(int paymentId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaymentReceiptPage(
        controller: widget.controller,
        paymentId: paymentId,
      ),
    ));
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
        title: const Text('Payment History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _blue,
                  child: _payments.isEmpty ? _buildEmpty() : _buildList(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 52, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          const Text('Unable to load data.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                  color: Color(0xFF374151))),
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

  Widget _buildEmpty() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No payment history yet.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildList() {
    final sections = _grouped;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        // ── Summary card ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Total Paid (All Semesters)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                Text(_fmtAmount(_totalPaid),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Transactions',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              Text('${_payments.length}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: _blue)),
            ]),
          ]),
        ),

        const SizedBox(height: 24),

        // ── Grouped sections ──────────────────────────────────────────────
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(section.key,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280), letterSpacing: 0.5)),
          ),
          ...section.value.map((p) => _PaymentCard(
            payment: p,
            methodLabel: _methodLabel(p['payment_method'] as String),
            dateTimeStr: _formatDateTime(p['paid_at'] as String),
            onReceiptTap: () => _openReceipt(p['id'] as int),
          )),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Payment card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.methodLabel,
    required this.dateTimeStr,
    required this.onReceiptTap,
  });

  final Map<String, dynamic> payment;
  final String methodLabel, dateTimeStr;
  final VoidCallback onReceiptTap;

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num).toDouble();
    final ref    = payment['reference_no'] as String;
    final desc   = payment['fee_description'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status icon
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 24),
            ),
            const SizedBox(width: 12),

            // Description + date + method
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(desc,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text(dateTimeStr,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 1),
                Text(methodLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
            ),

            // Amount + status badge
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15,
                      color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('SUCCESS',
                    style: TextStyle(
                        color: Color(0xFF16A34A), fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ),
            ]),
          ]),
        ),

        // Divider + reference + receipt link
        const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 14, endIndent: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            Text(ref,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            const Spacer(),
            GestureDetector(
              onTap: onReceiptTap,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.download_outlined, size: 14, color: Color(0xFF1565C0)),
                SizedBox(width: 4),
                Text('Receipt',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
