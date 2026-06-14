import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  static const _blue = Color(0xFF1E5BFF);
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
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _methodLabel(String m) => switch (m) {
    'online_banking' => 'Online Banking',
    'card'           => 'Card',
    'ewallet'        => 'e-Wallet',
    'cash'           => 'Cash',
    _                => m,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: const Text('Payment History',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF6B7280))))
              : _payments.isEmpty
                  ? const Center(child: Text('No payments yet.', style: TextStyle(color: Color(0xFF9CA3AF))))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _blue,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: _payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = _payments[i] as Map<String, dynamic>;
                          final paidAt = DateTime.tryParse(p['paid_at'] as String? ?? '');
                          final dateStr = paidAt != null
                              ? '${paidAt.day}/${paidAt.month}/${paidAt.year}  ${paidAt.hour.toString().padLeft(2, '0')}:${paidAt.minute.toString().padLeft(2, '0')}'
                              : '-';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
                            ),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.check_circle_outline,
                                    color: Color(0xFF16A34A), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['fee_description'] as String? ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF111827))),
                                  Text(_methodLabel(p['payment_method'] as String),
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                  Text(p['fee_semester'] as String? ?? '',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                ],
                              )),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('RM ${(p['amount'] as num).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF16A34A))),
                                const SizedBox(height: 2),
                                Text(dateStr,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                              ]),
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}
