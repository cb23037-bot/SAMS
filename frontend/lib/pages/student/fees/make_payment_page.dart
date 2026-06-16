import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../services/api_service.dart';
import 'payment_receipt_page.dart';

class MakePaymentPage extends StatefulWidget {
  const MakePaymentPage({
    super.key,
    required this.controller,
    required this.feeId,
    required this.balance,
    required this.description,
  });
  final AppController controller;
  final int feeId;
  final double balance;
  final String description;

  @override
  State<MakePaymentPage> createState() => _MakePaymentPageState();
}

class _MakePaymentPageState extends State<MakePaymentPage> {
  static const _blue = Color(0xFF1E5BFF);

  final _amountCtrl = TextEditingController();
  String _method    = 'online_banking';
  bool _paying      = false;
  String? _amtError;

  final _methods = const [
    ('online_banking', 'Online Banking', Icons.account_balance_outlined),
    ('card',           'Debit / Credit Card', Icons.credit_card_outlined),
    ('ewallet',        'e-Wallet',       Icons.wallet_outlined),
    ('cash',           'Cash',           Icons.money_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.balance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // Validates the entered amount (must be > 0 and <= outstanding balance),
  // then calls makePayment() via the API service. On success, replaces the
  // current route with PaymentReceiptPage so the student cannot go back to
  // this page and accidentally re-submit. On GATEWAY_UNAVAILABLE, shows a
  // dialog; for other errors, shows a red snackbar.
  Future<void> _submit() async {
    final amt = double.tryParse(_amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      setState(() => _amtError = 'Enter a valid amount.');
      return;
    }
    if (amt > widget.balance) {
      setState(() => _amtError = 'Cannot exceed balance of RM ${widget.balance.toStringAsFixed(2)}.');
      return;
    }
    setState(() { _amtError = null; _paying = true; });

    try {
      final result = await widget.controller.apiService.makePayment(
        token:         widget.controller.token!,
        feeId:         widget.feeId,
        amount:        amt,
        paymentMethod: _method,
      );
      if (!mounted) return;
      final paymentId      = (result['payment'] as Map<String, dynamic>)['id'] as int;
      final accessRestored = result['access_restored'] == true;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PaymentReceiptPage(
          controller:     widget.controller,
          paymentId:      paymentId,
          accessRestored: accessRestored,
          isNewPayment:   true,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : null;
      if (code == 'GATEWAY_UNAVAILABLE') {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Payment Unavailable'),
            content: const Text(
                'The payment service is currently unavailable. Please try again later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
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
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Balance chip
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text('RM ${widget.balance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              const Text('Outstanding Balance',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 24),

          // Amount field
          const Text('Amount (RM)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: 'RM ',
              hintText: '0.00',
              errorText: _amtError,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 2),
              ),
            ),
            onChanged: (_) => setState(() => _amtError = null),
          ),

          const SizedBox(height: 24),
          const Text('Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF374151))),
          const SizedBox(height: 10),

          ..._methods.map((m) {
            final (val, label, icon) = m;
            final selected = _method == val;
            return GestureDetector(
              onTap: () => setState(() => _method = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFEEF3FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _blue : const Color(0xFFE5E7EB),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(icon, color: selected ? _blue : const Color(0xFF6B7280), size: 22),
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? _blue : const Color(0xFF374151))),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle, color: _blue, size: 20),
                ]),
              ),
            );
          }),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _paying ? null : _submit,
              child: _paying
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Confirm Payment',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

