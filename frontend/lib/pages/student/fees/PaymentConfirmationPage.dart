import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_controller.dart';
import 'ReceiptPage.dart';

class PaymentConfirmationPage extends StatelessWidget {
  const PaymentConfirmationPage({
    super.key,
    required this.controller,
    required this.success,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.receiptNumber,
    this.errorCode,
  });

  final AppController controller;
  final bool success;
  final double amount;
  final String paymentMethod;
  final String? transactionId;
  final String? receiptNumber;
  final String? errorCode;

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  String get _nowFormatted {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '${now.day} ${months[now.month - 1]} ${now.year}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          success ? 'Payment Successful' : 'Payment Failed',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _statusIcon(),
            const SizedBox(height: 20),
            Text(
              success ? 'Payment Successful' : 'Payment Unsuccessful',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              success
                  ? 'Academic fees processed successfully.'
                  : 'Something went wrong with your transaction.',
              style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _detailsCard(context),
            const SizedBox(height: 32),
            _actionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: success
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE),
        shape: BoxShape.circle,
      ),
      child: Icon(
        success ? Icons.check_circle_outline : Icons.cancel_outlined,
        size: 48,
        color: success ? const Color(0xFF43A047) : const Color(0xFFE53935),
      ),
    );
  }

  Widget _detailsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          _detailRow('Amount', _fmt(amount)),
          const Divider(height: 20),
          _detailRow('Date / Time', _nowFormatted),
          const Divider(height: 20),
          if (transactionId != null && transactionId!.isNotEmpty) ...[
            _detailRowCopy(context, 'Transaction ID', transactionId!),
            const Divider(height: 20),
          ],
          _detailRow('Method', paymentMethod),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status',
                  style: TextStyle(color: Color(0xFF5B6B86), fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  success ? 'COMPLETED' : 'FAILED',
                  style: TextStyle(
                    color: success ? const Color(0xFF43A047) : const Color(0xFFE53935),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (!success && errorCode != null) ...[
            const Divider(height: 20),
            _detailRow('Error', errorCode!),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 14)),
        Flexible(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }

  Widget _detailRowCopy(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 14)),
        Row(
          children: [
            Flexible(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  textAlign: TextAlign.end),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Icon(Icons.copy_outlined, size: 16, color: Color(0xFF5B6B86)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButtons(BuildContext context) {
    if (success) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: receiptNumber != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptPage(
                            controller: controller,
                            receiptNumber: receiptNumber!,
                            studentName: controller.currentUser!.name,
                            amount: amount,
                          ),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.receipt_outlined),
              label: const Text('View Receipt', style: TextStyle(fontWeight: FontWeight.w700)),
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
              onPressed: () => Navigator.of(context)
                  .popUntil((route) => route.isFirst || route.settings.name == '/'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E5BFF),
                side: const BorderSide(color: Color(0xFF1E5BFF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back to Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Payment', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
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
            child: const Text('Back to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
