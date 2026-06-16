import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../utils/parse.dart';
import 'unpaid_fees_monitor_page.dart';

class TreasuryDashboardPage extends StatefulWidget {
  const TreasuryDashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<TreasuryDashboardPage> createState() => _TreasuryDashboardPageState();
}

class _TreasuryDashboardPageState extends State<TreasuryDashboardPage> {
  static const _teal = Color(0xFF00897B);

  int _tab = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Fetches high-level financial statistics from GET /api/treasury/dashboard:
  // total fees, total paid/unpaid, restriction count, current semester week,
  // and the 5 most recent payments. Populates _data for the dashboard widgets.
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getTreasuryDashboard(
        token: widget.controller.token!,
      );
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1A00897B),
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), label: 'Unpaid'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: IndexedStack(index: _tab, children: [
          _buildDashboard(),
          UnpaidFeesMonitorPage(controller: widget.controller, embedded: true),
          _buildSettings(),
        ])),
      ])),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.account_balance_outlined, color: _teal, size: 22),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Treasury', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827))),
          Text('Fee Management', style: TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
        ])),
        IconButton(
          tooltip: 'Logout',
          onPressed: widget.controller.signOut,
          icon: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
        ),
      ]),
    );
  }

  // Builds the main dashboard body using _data (loaded by _load()).
  // Shows stat cards (total fees, paid, unpaid, restrictions, semester week)
  // and a list of the 5 most recent successful payments.
  // Returns a loading spinner or error view while data is unavailable.
  Widget _buildDashboard() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _teal));
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: _teal), child: const Text('Retry')),
      ]));
    }

    final stats  = _data!['stats'] as Map<String, dynamic>;
    final recent = _data!['recent_payments'] as List<dynamic>? ?? [];
    final week   = stats['current_week'] as int?;

    return RefreshIndicator(
      onRefresh: _load,
      color: _teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (week != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: week >= 5 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: week >= 5 ? const Color(0xFFFFCC02) : const Color(0xFFA5D6A7)),
              ),
              child: Row(children: [
                Icon(week >= 5 ? Icons.warning_amber_outlined : Icons.event_outlined,
                    color: week >= 5 ? const Color(0xFFF57C00) : const Color(0xFF388E3C), size: 20),
                const SizedBox(width: 8),
                Text('Academic Week $week${week >= 5 ? " — Week 5 restriction active" : ""}',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: week >= 5 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                    )),
              ]),
            ),

          _TealStatCard(
            title: 'Total Collected',
            amount: parseDouble(stats['total_paid']),
            subtitle: 'of RM ${parseDouble(stats['total_fees']).toStringAsFixed(2)} billed',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _SmallStat(
              label: 'Outstanding', color: const Color(0xFFFFEBEE), textColor: const Color(0xFFDC2626),
              value: 'RM ${parseDouble(stats['total_unpaid']).toStringAsFixed(2)}',
            )),
            const SizedBox(width: 12),
            Expanded(child: _SmallStat(
              label: 'Unpaid Records', color: const Color(0xFFFFF3E0), textColor: const Color(0xFFF57C00),
              value: '${stats['unpaid_count']}',
            )),
            const SizedBox(width: 12),
            Expanded(child: _SmallStat(
              label: 'Restricted', color: const Color(0xFFFCE4EC), textColor: const Color(0xFFC62828),
              value: '${stats['restricted'] ?? 0}',
            )),
          ]),

          const SizedBox(height: 24),
          const Text('Recent Payments',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 10),

          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No payments yet.', style: TextStyle(color: Color(0xFF9CA3AF)))),
            )
          else
            ...recent.map((p) => _RecentPaymentRow(p: p as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return const Center(
      child: Text(
        'Settings coming soon.',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TealStatCard extends StatelessWidget {
  const _TealStatCard({required this.title, required this.amount, required this.subtitle, required this.icon});
  final String title, subtitle;
  final double amount;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF005F56)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('RM ${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Icon(icon, color: Colors.white38, size: 44),
      ]),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value, required this.color, required this.textColor});
  final String label, value;
  final Color color, textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
      ]),
    );
  }
}

class _RecentPaymentRow extends StatelessWidget {
  const _RecentPaymentRow({required this.p});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final paidAt = DateTime.tryParse(p['paid_at'] as String? ?? '');
    final date   = paidAt != null ? '${paidAt.day}/${paidAt.month}/${paidAt.year}' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.payments_outlined, color: Color(0xFF00897B), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['student_name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF111827))),
          Text('${p['student_id']} • ${p['fee_description']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('RM ${parseDouble(p['amount']).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF00897B))),
          Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        ]),
      ]),
    );
  }
}
