import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'MakePaymentPage.dart';

class FeeDetailsPage extends StatefulWidget {
  const FeeDetailsPage({super.key, required this.controller, required this.feeId});

  final AppController controller;
  final int feeId;

  @override
  State<FeeDetailsPage> createState() => _FeeDetailsPageState();
}

class _FeeDetailsPageState extends State<FeeDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _fee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.controller.apiService
          .getFeeDetails(feeId: widget.feeId, token: widget.controller.token!);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fee = data['fee'] as Map<String, dynamic>?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fee = {
          'id': widget.feeId,
          'semester': '2025/2026-1',
          'status': 'Partial',
          'total_amount': 8450.00,
          'outstanding_amount': 1510.00,
          'due_date': '2025-10-15',
        };
      });
    }
  }

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':    return const Color(0xFF43A047);
      case 'Unpaid':  return const Color(0xFFE53935);
      default:        return const Color(0xFFF57C00);
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
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fee == null
              ? const Center(child: Text('Fee not found.'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final fee             = _fee!;
    final status          = fee['status'] as String? ?? 'Unpaid';
    final totalAmount     = (fee['total_amount'] as num?)?.toDouble() ?? 0;
    final outstanding     = (fee['outstanding_amount'] as num?)?.toDouble() ?? 0;
    final paid            = totalAmount - outstanding;
    final tuition         = totalAmount * 0.85;
    final misc            = totalAmount - tuition;
    final dueDate         = fee['due_date'] as String? ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Semester ${fee['semester'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Due: $dueDate',
                        style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment breakdown
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PAYMENT BREAKDOWN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF5B6B86))),
                const SizedBox(height: 14),
                _breakdownRow('Tuition Fee', 'CORE MODULES', tuition, false),
                const SizedBox(height: 12),
                _breakdownRow('Miscellaneous Fee', 'LIBRARY & LAB ACCESS', misc, false),
                const Divider(height: 24),
                _breakdownRow('TOTAL AMOUNT', '(incl. service tax)', totalAmount, true),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Paid vs Outstanding
          _card(
            child: Column(
              children: [
                _summaryRow('Amount Paid', _fmt(paid), const Color(0xFF43A047)),
                const Divider(height: 16),
                _summaryRow('Outstanding', _fmt(outstanding),
                    outstanding > 0 ? const Color(0xFFE53935) : const Color(0xFF43A047)),
              ],
            ),
          ),

          if (outstanding > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Color(0xFFF57C00)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please settle your outstanding balance before the due date to avoid academic restrictions.',
                      style: TextStyle(color: Color(0xFFF57C00), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download Invoice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E5BFF),
                    side: const BorderSide(color: Color(0xFF1E5BFF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (outstanding > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MakePaymentPage(
                          controller: widget.controller,
                          feeId: (fee['id'] as int?) ?? widget.feeId,
                          outstandingAmount: outstanding,
                        ),
                      ),
                    ).then((_) => _load()),
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String sub, double amount, bool bold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      fontSize: bold ? 15 : 14,
                      color: const Color(0xFF111827))),
              Text(sub,
                  style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
            ],
          ),
        ),
        Text(
          _fmt(amount),
          style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: bold ? const Color(0xFF111827) : const Color(0xFF5B6B86)),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF5B6B86))),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
