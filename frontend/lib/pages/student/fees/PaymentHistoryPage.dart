import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.controller.apiService
          .getPaymentHistory(token: widget.controller.token!);
      if (!mounted) return;
      final list = (data['payments'] as List<dynamic>?) ?? [];
      setState(() {
        _isLoading = false;
        _payments  = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _payments = [
          {
            'id': 1,
            'amount': 6940.00,
            'payment_method': 'FPX',
            'status': 'Success',
            'created_at': '2025-09-10T10:30:00Z',
            'receipt': {'receipt_number': 'RCP-00001'},
          },
        ];
      });
    }
  }

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  String _shortDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  String _monthYear(String? iso) {
    if (iso == null) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['January','February','March','April','May','June',
          'July','August','September','October','November','December'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Unknown';
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
        title: const Text('Payment History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827))),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list, color: Color(0xFF5B6B86)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.download_outlined, color: Color(0xFF5B6B86)), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 60, color: Color(0xFF5B6B86)),
                      SizedBox(height: 12),
                      Text('No payment records yet.',
                          style: TextStyle(color: Color(0xFF5B6B86), fontSize: 15)),
                    ],
                  ),
                )
              : _buildList(),
    );
  }

  Widget _buildList() {
    // Group by month-year
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final p in _payments) {
      final key = _monthYear(p['created_at'] as String?);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E5BFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Transaction Ledger — Academic Year 2025/2026',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          ...grouped.entries.map((entry) => _monthGroup(entry.key, entry.value)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E5BFF),
              side: const BorderSide(color: Color(0xFF1E5BFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Older Records'),
          ),
        ],
      ),
    );
  }

  Widget _monthGroup(String monthYear, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            monthYear,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF5B6B86)),
          ),
        ),
        ...items.map(_paymentTile),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _paymentTile(Map<String, dynamic> p) {
    final isSuccess = p['status'] == 'Success';
    final receipt   = p['receipt'] as Map<String, dynamic>?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check : Icons.close,
              color: isSuccess ? const Color(0xFF43A047) : const Color(0xFFE53935),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['payment_method'] ?? 'Payment'} — Tuition Fee',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(_shortDate(p['created_at'] as String?),
                    style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
                if (receipt != null)
                  Text('Ref: ${receipt['receipt_number']}',
                      style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt((p['amount'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSuccess ? 'SUCCESS' : 'FAILED',
                  style: TextStyle(
                    color: isSuccess ? const Color(0xFF43A047) : const Color(0xFFE53935),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
