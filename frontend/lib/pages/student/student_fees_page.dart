import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class StudentFeesContent extends StatefulWidget {
  const StudentFeesContent({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final AppController controller;
  final VoidCallback onBack;

  @override
  State<StudentFeesContent> createState() => _StudentFeesContentState();
}

class _StudentFeesContentState extends State<StudentFeesContent> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _fees = [];

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final json = await widget.controller.apiService.getStudentFees(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      setState(() {
        _summary = (json['summary'] as Map<String, dynamic>?) ?? {};
        _fees = ((json['fees'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFees,
      color: const Color(0xFF1E5BFF),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _FeesHeader(onBack: widget.onBack),
                const SizedBox(height: 16),
                if (_isLoading)
                  const _FeesLoadingState()
                else if (_error != null)
                  _FeesErrorState(message: _error!, onRetry: _loadFees)
                else ...[
                  _FeesSummaryCard(summary: _summary ?? const {}),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Manage Fees',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Refresh fees',
                        onPressed: _loadFees,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_fees.isEmpty)
                    const _EmptyFeesState()
                  else
                    ..._fees.map(
                      (fee) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FeeCard(
                          fee: fee,
                          onPay: () => _showPaymentSheet(fee),
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaymentSheet(Map<String, dynamic> fee) async {
    final paid = fee['status'] == 'paid';
    if (paid) return;

    final paidResult = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PaymentSheet(controller: widget.controller, fee: fee),
    );

    if (paidResult == true) {
      await _loadFees();
    }
  }
}

class _FeesHeader extends StatelessWidget {
  const _FeesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fees',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review balances and make payments',
                style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeesSummaryCard extends StatelessWidget {
  const _FeesSummaryCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final total = _asDouble(summary['total']);
    final paid = _asDouble(summary['paid']);
    final unpaid = _asDouble(summary['unpaid']);
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16213E), Color(0xFF1E5BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241E5BFF),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outstanding Balance',
            style: TextStyle(
              color: Color(0xD9FFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(unpaid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7DD3FC),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'Total', value: _money(total)),
              ),
              Expanded(
                child: _SummaryMetric(label: 'Paid', value: _money(paid)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.fee, required this.onPay});

  final Map<String, dynamic> fee;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final amount = _asDouble(fee['amount']);
    final paid = _asDouble(fee['amount_paid']);
    final balance = _asDouble(fee['balance']);
    final status = (fee['status'] ?? 'unpaid').toString();
    final isPaid = status == 'paid';
    final progress = amount <= 0 ? 0.0 : (paid / amount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100D1B2A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: _statusColor(status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (fee['description'] ?? 'Student Fee').toString(),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fee['semester'] ?? '-'} - Due ${fee['due_date'] ?? '-'}',
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: const Color(0xFFE8EDF6),
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor(status)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FeeAmount(label: 'Amount', value: _money(amount)),
              ),
              Expanded(
                child: _FeeAmount(label: 'Paid', value: _money(paid)),
              ),
              Expanded(
                child: _FeeAmount(label: 'Balance', value: _money(balance)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isPaid ? null : onPay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E5BFF),
                disabledBackgroundColor: const Color(0xFFE8EDF6),
                disabledForegroundColor: const Color(0xFF5B6B86),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                isPaid ? Icons.check_circle_outline : Icons.payments_outlined,
              ),
              label: Text(
                isPaid ? 'Paid in Full' : 'Pay Balance',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeAmount extends StatelessWidget {
  const _FeeAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8A96A8), fontSize: 12),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = switch (status) {
      'paid' => 'Paid',
      'partial' => 'Partial',
      _ => 'Unpaid',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.controller, required this.fee});

  final AppController controller;
  final Map<String, dynamic> fee;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  String _method = 'online_banking';
  bool _isSubmitting = false;

  double get _balance => _asDouble(widget.fee['balance']);

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _balance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E0F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Make Payment',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Remaining balance ${_money(_balance)}',
                style: const TextStyle(color: Color(0xFF5B6B86)),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _sheetInputDecoration(
                  label: 'Amount',
                  prefix: 'RM',
                  icon: Icons.attach_money,
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount.';
                  }
                  if (amount > _balance) {
                    return 'Amount cannot exceed the balance.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: _sheetInputDecoration(
                  label: 'Payment Method',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'online_banking',
                    child: Text('Online Banking'),
                  ),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _method = value!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: const Text(
                    'Confirm Payment',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.controller.apiService.makePayment(
        token: widget.controller.token!,
        feeId: widget.fee['id'] as int,
        amount: double.parse(_amountController.text.trim()),
        paymentMethod: _method,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _FeesLoadingState extends StatelessWidget {
  const _FeesLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator(color: Color(0xFF1E5BFF))),
    );
  }
}

class _FeesErrorState extends StatelessWidget {
  const _FeesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.error_outline,
      title: 'Unable to load fees',
      message: message,
      actionLabel: 'Try Again',
      onAction: onRetry,
    );
  }
}

class _EmptyFeesState extends StatelessWidget {
  const _EmptyFeesState();

  @override
  Widget build(BuildContext context) {
    return const _StatePanel(
      icon: Icons.check_circle_outline,
      title: 'No fee records',
      message: 'Your fee records will appear here once they are assigned.',
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1E5BFF), size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5B6B86)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

InputDecoration _sheetInputDecoration({
  required String label,
  required IconData icon,
  String? prefix,
}) {
  return InputDecoration(
    labelText: label,
    prefixText: prefix == null ? null : '$prefix ',
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF8FAFD),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
    ),
  );
}

Color _statusColor(String status) {
  return switch (status) {
    'paid' => const Color(0xFF16A34A),
    'partial' => const Color(0xFFF97316),
    _ => const Color(0xFFEF4444),
  };
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(double value) => 'RM ${value.toStringAsFixed(2)}';
