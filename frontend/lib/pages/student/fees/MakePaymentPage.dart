import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'PaymentConfirmationPage.dart';

class MakePaymentPage extends StatefulWidget {
  const MakePaymentPage({
    super.key,
    required this.controller,
    required this.feeId,
    required this.outstandingAmount,
  });

  final AppController controller;
  final int feeId;
  final double outstandingAmount;

  @override
  State<MakePaymentPage> createState() => _MakePaymentPageState();
}

class _MakePaymentPageState extends State<MakePaymentPage> {
  String _selectedMethod = 'FPX';
  late final TextEditingController _amountController;
  bool _isProcessing = false;

  static const _blue = Color(0xFF1E5BFF);

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.outstandingAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount.'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }
    if (amount > widget.outstandingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount cannot exceed outstanding balance (RM ${widget.outstandingAmount.toStringAsFixed(2)}).'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await widget.controller.apiService.makePayment(
        token: widget.controller.token!,
        feeId: widget.feeId,
        amount: amount,
        paymentMethod: _selectedMethod,
      );

      if (!mounted) return;

      final success       = result['success'] == true;
      final transactionId = result['transaction_id'] as String? ?? '';
      final receiptNumber = result['receipt_number'] as String? ?? '';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentConfirmationPage(
            controller: widget.controller,
            success: success,
            amount: amount,
            paymentMethod: _selectedMethod,
            transactionId: transactionId,
            receiptNumber: receiptNumber,
            errorCode: success ? null : (result['message'] as String? ?? 'ERR-001'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentConfirmationPage(
            controller: widget.controller,
            success: false,
            amount: amount,
            paymentMethod: _selectedMethod,
            transactionId: null,
            receiptNumber: null,
            errorCode: e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
        title: const Text('Make Payment',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outstanding balance banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outstanding Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    'RM ${widget.outstandingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Amount input
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Amount',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: 'RM ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                      ),
                      hintText: '0.00',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment method
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  _methodTile('FPX', 'Online Banking', Icons.account_balance_outlined),
                  _methodTile('Credit Card', 'Visa / Mastercard', Icons.credit_card_outlined),
                  _methodTile('Manual', 'Manual / Counter Payment', Icons.payments_outlined),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Pay Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodTile(String value, String subtitle, IconData icon) {
    final selected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? _blue : const Color(0xFFE8EDF6), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? const Color(0xFFF1F6FF) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _blue : const Color(0xFF5B6B86)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? _blue : const Color(0xFF111827))),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedMethod,
              onChanged: (v) => setState(() => _selectedMethod = v!),
              activeColor: _blue,
            ),
          ],
        ),
      ),
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
