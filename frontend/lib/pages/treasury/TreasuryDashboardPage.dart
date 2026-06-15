import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'FeeRecordsListPage.dart';
import 'UnpaidFeesMonitorPage.dart';

class TreasuryDashboardPage extends StatefulWidget {
  const TreasuryDashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<TreasuryDashboardPage> createState() => _TreasuryDashboardPageState();
}

class _TreasuryDashboardPageState extends State<TreasuryDashboardPage> {
  int _selectedIndex = 0;

  bool _isLoading = true;
  int _totalStudents   = 0;
  int _paidCount       = 0;
  int _unpaidCount     = 0;
  double _totalCollected   = 0;
  double _totalOutstanding = 0;
  List<Map<String, dynamic>> _recentTransactions = [];

  static const _teal = Color(0xFF00897B);
  static const _blue = Color(0xFF1E5BFF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.controller.apiService
          .getTreasuryStats(token: widget.controller.token!);
      if (!mounted) return;
      final txns = (data['recent_transactions'] as List<dynamic>?) ?? [];
      setState(() {
        _isLoading        = false;
        _totalStudents    = (data['total_students'] as num?)?.toInt() ?? 0;
        _paidCount        = (data['total_paid_count'] as num?)?.toInt() ?? 0;
        _unpaidCount      = (data['total_unpaid_count'] as num?)?.toInt() ?? 0;
        _totalCollected   = (data['total_collected'] as num?)?.toDouble() ?? 0;
        _totalOutstanding = (data['total_outstanding'] as num?)?.toDouble() ?? 0;
        _recentTransactions = txns.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading        = false;
        _totalStudents    = 3;
        _paidCount        = 1;
        _unpaidCount      = 2;
        _totalCollected   = 15390.00;
        _totalOutstanding = 4710.00;
        _recentTransactions = [
          {'student_name': 'Ahmad Syahmi', 'amount': 6940.00, 'payment_method': 'FPX', 'created_at': '2025-09-10T10:30:00Z'},
          {'student_name': 'Haziq Danial', 'amount': 8450.00, 'payment_method': 'Credit Card', 'created_at': '2025-09-08T14:20:00Z'},
        ];
      });
    }
  }

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  String _shortDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1A00897B),
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none_outlined), label: 'Alerts'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _selectedIndex == 0
                  ? _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _homeView()
                  : _selectedIndex == 3
                      ? _profileView()
                      : const Center(child: Text('Coming soon.', style: TextStyle(color: Color(0xFF5B6B86)))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0xFFF1F6FF),
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(6),
            child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SA Management',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Color(0xFF111827))),
                Text('Treasury Portal',
                    style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _teal.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_circle_outlined, color: _teal, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _homeView() {
    final total = _paidCount + _unpaidCount;
    final paidPct = total > 0 ? (_paidCount / total * 100).round() : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + title
            const Text('ADMINISTRATIVE TERMINAL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _teal)),
            const SizedBox(height: 4),
            const Text('Treasury Overview',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 16),

            // Stat cards
            Row(
              children: [
                Expanded(child: _statCard('Total Students', '$_totalStudents', Icons.people_outline, _blue, '+12%', true)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Paid', '$_paidCount ($paidPct%)', Icons.check_circle_outline, const Color(0xFF43A047), null, false)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Unpaid', '$_unpaidCount', Icons.warning_amber_outlined, const Color(0xFFE53935), null, false)),
              ],
            ),

            const SizedBox(height: 16),

            // Summary totals
            _card(
              child: Column(
                children: [
                  _totalsRow('Total Collected', _fmt(_totalCollected), const Color(0xFF43A047)),
                  const Divider(height: 16),
                  _totalsRow('Total Outstanding', _fmt(_totalOutstanding), const Color(0xFFE53935)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    'View Student Records',
                    Icons.list_alt_outlined,
                    _blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FeeRecordsListPage(controller: widget.controller)),
                    ).then((_) => _load()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    'Monitor Fees',
                    Icons.monitor_outlined,
                    const Color(0xFFE53935),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UnpaidFeesMonitorPage(controller: widget.controller)),
                    ).then((_) => _load()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Collection trend chart
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COLLECTION TREND',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xFF5B6B86))),
                  const SizedBox(height: 4),
                  const Text('Last 6 Months',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 20),
                  _barChart(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Recent activity
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECENT ACTIVITY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xFF5B6B86))),
                  const SizedBox(height: 12),
                  if (_recentTransactions.isEmpty)
                    const Text('No recent activity.',
                        style: TextStyle(color: Color(0xFF5B6B86)))
                  else
                    ..._recentTransactions.take(3).map(_activityTile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String? badge, bool showBadge) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              if (showBadge && badge != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Color(0xFF43A047), fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barChart() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    const values = [0.45, 0.6, 0.35, 0.8, 0.55, 0.9];
    const maxHeight = 80.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(months.length, (i) {
        return Column(
          children: [
            Container(
              width: 28,
              height: maxHeight * values[i],
              decoration: BoxDecoration(
                color: i == 5 ? _teal : _blue.withAlpha(180),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(months[i],
                style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86))),
          ],
        );
      }),
    );
  }

  Widget _activityTile(Map<String, dynamic> t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Color(0xFF43A047), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t['student_name']} — ${t['payment_method'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(_shortDate(t['created_at'] as String?),
                    style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
              ],
            ),
          ),
          Text(_fmt((t['amount'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _profileView() {
    final user = widget.controller.currentUser!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_teal, Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.account_circle, color: Colors.white, size: 60),
                const SizedBox(height: 12),
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('TREASURY OFFICER',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => widget.controller.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                backgroundColor: const Color(0xFFFFF5F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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

  Widget _totalsRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
