import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class TreasuryDashboardPage extends StatefulWidget {
  const TreasuryDashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<TreasuryDashboardPage> createState() => _TreasuryDashboardPageState();
}

class _TreasuryDashboardPageState extends State<TreasuryDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _fees = [];
  List<Map<String, dynamic>> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.controller.apiService.getTreasuryDashboard(
          token: widget.controller.token!,
        ),
        widget.controller.apiService.getFeeRecords(
          token: widget.controller.token!,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = (results[0]['stats'] as Map<String, dynamic>?) ?? {};
        _recentPayments =
            ((results[0]['recent_payments'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        _fees = ((results[1]['fees'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1E5BFF),
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(controller: widget.controller, onRefresh: _load),
                    const SizedBox(height: 18),
                    if (_loading)
                      const _LoadingState()
                    else if (_error != null)
                      _ErrorState(message: _error!, onRetry: _load)
                    else ...[
                      _StatsGrid(stats: _stats),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Fee Records',
                        count: _fees.length,
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 12),
                      if (_fees.isEmpty)
                        const _EmptyState(
                          title: 'No fee records',
                          message: 'Assigned student fees will appear here.',
                        )
                      else
                        ..._fees.map(
                          (fee) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FeeRecordCard(fee: fee),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _SectionHeader(
                        title: 'Recent Payments',
                        count: _recentPayments.length,
                        icon: Icons.payments_outlined,
                      ),
                      const SizedBox(height: 12),
                      if (_recentPayments.isEmpty)
                        const _EmptyState(
                          title: 'No payments yet',
                          message: 'Recent student payments will appear here.',
                        )
                      else
                        ..._recentPayments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PaymentRow(payment: payment),
                          ),
                        ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onRefresh});

  final AppController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF1E5BFF),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treasury Dashboard',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Monitor fees and student payments',
                      style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E5BFF),
                    side: const BorderSide(color: Color(0xFFD6E0F0)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.isLoading ? null : controller.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _StatTile(
          label: 'Total Fees',
          value: _money(_asDouble(stats['total_fees'])),
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF1E5BFF),
        ),
        _StatTile(
          label: 'Collected',
          value: _money(_asDouble(stats['total_paid'])),
          icon: Icons.check_circle_outline,
          color: const Color(0xFF16A34A),
        ),
        _StatTile(
          label: 'Outstanding',
          value: _money(_asDouble(stats['total_unpaid'])),
          icon: Icons.warning_amber_outlined,
          color: const Color(0xFFF97316),
        ),
        _StatTile(
          label: 'Unpaid Count',
          value: _asInt(stats['unpaid_count']).toString(),
          icon: Icons.pending_actions_outlined,
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E5BFF), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Color(0xFF1E5BFF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeeRecordCard extends StatelessWidget {
  const _FeeRecordCard({required this.fee});

  final Map<String, dynamic> fee;

  @override
  Widget build(BuildContext context) {
    final status = (fee['status'] ?? 'unpaid').toString();
    final amount = _asDouble(fee['amount']);
    final paid = _asDouble(fee['amount_paid']);
    final balance = _asDouble(fee['balance']);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (fee['student_name'] ?? 'Student').toString(),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fee['student_id'] ?? '-'} - ${fee['semester'] ?? '-'}',
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
          const SizedBox(height: 12),
          Text(
            (fee['description'] ?? 'Fee record').toString(),
            style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _AmountColumn(label: 'Amount', value: amount),
              ),
              Expanded(
                child: _AmountColumn(label: 'Paid', value: paid),
              ),
              Expanded(
                child: _AmountColumn(label: 'Balance', value: balance),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F9EE),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (payment['student_name'] ?? 'Student').toString(),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (payment['reference_no'] ?? '-').toString(),
                  style: const TextStyle(
                    color: Color(0xFF5B6B86),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _money(_asDouble(payment['amount'])),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({required this.label, required this.value});

  final String label;
  final double value;

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
          _money(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 90),
      child: Center(child: CircularProgressIndicator(color: Color(0xFF1E5BFF))),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.error_outline,
      title: 'Unable to load treasury',
      message: message,
      actionLabel: 'Try Again',
      onAction: onRetry,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.inbox_outlined,
      title: title,
      message: message,
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

Color _statusColor(String status) {
  return switch (status.toLowerCase()) {
    'paid' => const Color(0xFF16A34A),
    'partial' => const Color(0xFFF97316),
    _ => const Color(0xFFEF4444),
  };
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _money(double value) => 'RM ${value.toStringAsFixed(2)}';
