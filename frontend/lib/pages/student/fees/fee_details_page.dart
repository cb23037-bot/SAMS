import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'make_payment_page.dart';

class FeeDetailsPage extends StatefulWidget {
  const FeeDetailsPage({super.key, required this.controller, required this.feeId});
  final AppController controller;
  final int feeId;

  @override
  State<FeeDetailsPage> createState() => _FeeDetailsPageState();
}

class _FeeDetailsPageState extends State<FeeDetailsPage> {
  static const _blue = Color(0xFF1E5BFF);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _fee;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getFeeDetails(
        token: widget.controller.token!,
        feeId: widget.feeId,
      );
      setState(() {
        _fee      = data['fee'] as Map<String, dynamic>;
        _payments = data['payments'] as List<dynamic>? ?? [];
        _loading  = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: const Text('Fee Details',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final fee    = _fee!;
    final status = fee['status'] as String;
    final (label, bg, fg) = switch (status) {
      'paid'    => ('Paid',    const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'partial' => ('Partial', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      _         => ('Unpaid',  const Color(0xFFFFEBEE), const Color(0xFFDC2626)),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(fee['description'] as String,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(fee['semester'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Row(children: [
                _WhiteStatCol(label: 'Total', value: (fee['amount'] as num).toDouble()),
                const SizedBox(width: 20),
                _WhiteStatCol(label: 'Paid', value: (fee['amount_paid'] as num).toDouble()),
                const SizedBox(width: 20),
                _WhiteStatCol(label: 'Balance', value: (fee['balance'] as num).toDouble()),
              ]),
              const SizedBox(height: 8),
              Text('Due: ${fee['due_date']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),

        if (status != 'paid') ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MakePaymentPage(
                controller: widget.controller,
                feeId: fee['id'] as int,
                balance: (fee['balance'] as num).toDouble(),
                description: fee['description'] as String,
              ),
            )).then((_) => _load()),
            icon: const Icon(Icons.payment_outlined),
            label: const Text('Make Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],

        const SizedBox(height: 24),
        Text('Payment History (${_payments.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 10),

        if (_payments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No payments made yet.', style: TextStyle(color: Color(0xFF9CA3AF)))),
          )
        else
          ..._payments.map((p) => _PaymentRow(payment: p as Map<String, dynamic>)),
      ],
    );
  }
}

class _WhiteStatCol extends StatelessWidget {
  const _WhiteStatCol({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 2),
      Text('RM ${value.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    ]);
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});
  final Map<String, dynamic> payment;

  String _methodLabel(String m) => switch (m) {
    'online_banking' => 'Online Banking',
    'card'           => 'Card',
    'ewallet'        => 'e-Wallet',
    'cash'           => 'Cash',
    _                => m,
  };

  @override
  Widget build(BuildContext context) {
    final paidAt = DateTime.tryParse(payment['paid_at'] as String? ?? '');
    final dateStr = paidAt != null
        ? '${paidAt.day}/${paidAt.month}/${paidAt.year}'
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RM ${(payment['amount'] as num).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
          Text(_methodLabel(payment['payment_method'] as String),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          const SizedBox(height: 2),
          Text(payment['reference_no'] as String,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
      ]),
    );
  }
}
