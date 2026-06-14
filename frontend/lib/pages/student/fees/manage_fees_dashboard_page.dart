import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'make_payment_page.dart';
import 'payment_history_page.dart';

class ManageFeesDashboardPage extends StatefulWidget {
  const ManageFeesDashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ManageFeesDashboardPage> createState() => _ManageFeesDashboardPageState();
}

class _ManageFeesDashboardPageState extends State<ManageFeesDashboardPage> {
  static const _blue    = Color(0xFF1E5BFF);
  static const _navy1   = Color(0xFF0B1D51);
  static const _navy2   = Color(0xFF1A3A8F);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  bool _restricted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.controller.apiService.getStudentFees(token: widget.controller.token!),
        widget.controller.apiService.getRestrictionStatus(token: widget.controller.token!),
      ]);
      setState(() {
        _data       = results[0];
        _restricted = results[1]['restricted'] == true;
        _loading    = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _blue))
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fees',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                Text('Review balances and make payments',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Payment History',
            icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF6B7280)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PaymentHistoryPage(controller: widget.controller),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final fees    = (_data!['fees'] as List<dynamic>?) ?? [];
    final summary = _data!['summary'] as Map<String, dynamic>? ?? {};
    final total   = (summary['total'] as num?)?.toDouble() ?? 0;
    final paid    = (summary['paid'] as num?)?.toDouble() ?? 0;
    final unpaid  = (summary['unpaid'] as num?)?.toDouble() ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: _blue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (_restricted) ...[
            _RestrictionBanner(),
            const SizedBox(height: 12),
          ],

          // ── Outstanding Balance Card ──────────────────────────────
          _BalanceCard(total: total, paid: paid, unpaid: unpaid),
          const SizedBox(height: 24),

          // ── Section header ────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text('Manage Fees',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Fee cards ─────────────────────────────────────────────
          if (fees.isEmpty)
            const _EmptyState()
          else
            ...fees.map((f) {
              final fee = f as Map<String, dynamic>;
              return _FeeCard(
                fee: fee,
                onPay: (fee['status'] as String) != 'paid'
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MakePaymentPage(
                            controller: widget.controller,
                            feeId: fee['id'] as int,
                            balance: (fee['balance'] as num).toDouble(),
                            description: fee['description'] as String,
                          ),
                        )).then((_) => _load())
                    : null,
              );
            }),
        ],
      ),
    );
  }
}

// ── Restriction Banner ────────────────────────────────────────────────────────

class _RestrictionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Academic access restricted — settle outstanding fees to restore access.',
            style: TextStyle(
                color: Color(0xFFB71C1C), fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ── Balance Card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.total, required this.paid, required this.unpaid});
  final double total, paid, unpaid;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1D51), Color(0xFF1A3A8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Outstanding Balance',
              style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('RM ${unpaid.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _BalanceStat(label: 'Total',  value: total),
            const SizedBox(width: 32),
            _BalanceStat(label: 'Paid',   value: paid),
          ]),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 2),
      Text('RM ${value.toStringAsFixed(2)}',
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Fee Card ──────────────────────────────────────────────────────────────────

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.fee, this.onPay});
  final Map<String, dynamic> fee;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final status  = fee['status'] as String;
    final amount  = (fee['amount'] as num).toDouble();
    final paid    = (fee['amount_paid'] as num).toDouble();
    final balance = (fee['balance'] as num).toDouble();
    final progress = amount > 0 ? (paid / amount).clamp(0.0, 1.0) : 0.0;

    final (label, badgeBg, badgeFg, barColor) = switch (status) {
      'paid'    => ('Paid',    const Color(0xFFDCFCE7), const Color(0xFF16A34A), const Color(0xFF22C55E)),
      'partial' => ('Partial', const Color(0xFFFEF3C7), const Color(0xFFD97706), const Color(0xFFF97316)),
      _         => ('Unpaid',  const Color(0xFFFFEBEE), const Color(0xFFDC2626), const Color(0xFFEF4444)),
    };

    final dueDate = fee['due_date'] as String? ?? '';
    final semester = fee['semester'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + badge
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_outlined, color: Color(0xFFF97316), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fee['description'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text('$semester  •  Due $dueDate',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: TextStyle(
                        color: badgeFg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),

            const SizedBox(height: 12),

            // Amount / Paid / Balance
            Row(children: [
              _StatCol(label: 'Amount',  value: amount),
              const SizedBox(width: 20),
              _StatCol(label: 'Paid',    value: paid),
              const SizedBox(width: 20),
              _StatCol(label: 'Balance', value: balance, highlight: balance > 0),
            ]),

            if (onPay != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onPay,
                  icon: const Icon(Icons.credit_card_outlined, size: 18),
                  label: const Text('Pay Balance',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value, this.highlight = false});
  final String label;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      const SizedBox(height: 2),
      Text('RM ${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFFDC2626) : const Color(0xFF111827))),
    ]);
  }
}

// ── Empty / Error ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Column(children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
        SizedBox(height: 12),
        Text('No fee records found.', style: TextStyle(color: Color(0xFF9CA3AF))),
      ])),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_outlined, size: 48, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E5BFF)),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}
