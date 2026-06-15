import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({
    super.key,
    required this.controller,
    required this.receiptNumber,
    required this.studentName,
    required this.amount,
  });

  final AppController controller;
  final String receiptNumber;
  final String studentName;
  final double amount;

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  String get _nowFormatted {
    final now = DateTime.now();
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: const Text('Academic Receipt',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827))),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF5B6B86)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _receiptCard(),
            const SizedBox(height: 24),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _receiptCard() {
    final tuition = amount * 0.85;
    final misc    = amount - tuition;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: const Column(
              children: [
                Text('SA Management',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                SizedBox(height: 4),
                Text('OFFICIAL PAYMENT VOUCHER',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 11, letterSpacing: 1.5)),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _receiptRow('STUDENT NAME', studentName),
                const SizedBox(height: 10),
                _receiptRow('DATE', _nowFormatted),
                const SizedBox(height: 10),
                _receiptRow('TRANSACTION ID', receiptNumber),
                const Divider(height: 28),

                // Line items
                const Text('LINE ITEMS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF5B6B86))),
                const SizedBox(height: 12),
                _lineItem('Tuition Fees — Sem 1', _fmt(tuition)),
                const SizedBox(height: 8),
                _lineItem('Lab & Library Dues', _fmt(misc)),
                const Divider(height: 24),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL AMOUNT',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Row(
                      children: [
                        Text(_fmt(amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Color(0xFF1E5BFF))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('PAID',
                              style: TextStyle(
                                  color: Color(0xFF43A047),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Security section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EDF6)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_2, size: 48, color: Color(0xFF1E5BFF)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scan for digital verification',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            SizedBox(height: 4),
                            Text('SECURELINK:ENCRYPTED',
                                style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: Color(0xFF5B6B86))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86),
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
        ),
      ],
    );
  }

  Widget _lineItem(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
        Text(amount,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B6B86),
              side: const BorderSide(color: Color(0xFFD6E0F0)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back to Finance',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
