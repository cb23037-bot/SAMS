import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import 'FeeDetailsPage.dart';
import 'MakePaymentPage.dart';
import 'PaymentHistoryPage.dart';

class ManageFeesDashboardPage extends StatefulWidget {
  const ManageFeesDashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ManageFeesDashboardPage> createState() => _ManageFeesDashboardPageState();
}

class _ManageFeesDashboardPageState extends State<ManageFeesDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  double _totalOutstanding = 0;
  bool _hasRestriction = false;
  List<Map<String, dynamic>> _recentFees = [];
  List<Map<String, dynamic>> _recentPayments = [];

  static const _blue = Color(0xFF1E5BFF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.controller.apiService
          .getStudentFees(token: widget.controller.token!);
      if (!mounted) return;
      final fees = (data['fees'] as List<dynamic>?) ?? [];
      final summary = data['summary'] as Map<String, dynamic>? ?? {};
      setState(() {
        _isLoading         = false;
        _totalOutstanding  = (summary['unpaid'] as num?)?.toDouble() ?? 0;
        _hasRestriction    = false;
        _recentFees        = fees.cast<Map<String, dynamic>>();
        _recentPayments    = [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading        = false;
        _totalOutstanding = 1510.00;
        _hasRestriction   = false;
        _recentFees = [
          {'id': 1, 'semester': '2025/2026-1', 'status': 'Partial', 'outstanding_amount': 1510.00, 'total_amount': 8450.00},
        ];
        _recentPayments = [
          {'id': 1, 'amount': 6940.00, 'payment_method': 'FPX', 'status': 'Success', 'created_at': '2025-09-10T10:30:00Z'},
        ];
      });
    }
  }

  String _fmt(double amount) => 'RM ${amount.toStringAsFixed(2)}';

  String _shortDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(user.name),
            if (_hasRestriction) _restrictionBanner(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _isLoading ? const Center(child: CircularProgressIndicator()) : _summaryTab(),
                  _sponsorTab(),
                  _paymentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(5),
            child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Financial Info',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF111827)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _restrictionBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE53935),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.block, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Academic Access Restricted — Please settle outstanding fees.',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _blue,
        unselectedLabelColor: const Color(0xFF5B6B86),
        indicatorColor: _blue,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [Tab(text: 'SUMMARY'), Tab(text: 'SPONSOR'), Tab(text: 'PAYMENT')],
      ),
    );
  }

  Widget _summaryTab() {
    final user = widget.controller.currentUser!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _outstandingCard(),
            const SizedBox(height: 16),
            _infoCard(user),
            const SizedBox(height: 16),
            _totalsCard(),
            const SizedBox(height: 16),
            _recentTransactionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _outstandingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OUTSTANDING BALANCE',
              style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(
            _fmt(_totalOutstanding),
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _totalOutstanding > 0
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MakePaymentPage(
                            controller: widget.controller,
                            feeId: _recentFees.isNotEmpty ? (_recentFees.first['id'] as int?) ?? 0 : 0,
                            outstandingAmount: _totalOutstanding,
                          ),
                        ),
                      ).then((_) => _load())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Pay Tuition Fee', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(user) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.course ?? 'Bachelor of Computer Science',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ACTIVE',
                    style: TextStyle(color: Color(0xFF43A047), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Student ID', user.studentId ?? '-'),
          _infoRow('Email', user.email),
          _infoRow('Semester', user.currentSemester ?? '-'),
        ],
      ),
    );
  }

  Widget _totalsCard() {
    final totalFee  = _recentFees.isNotEmpty ? (_recentFees.first['total_amount'] as num?)?.toDouble() ?? 0 : 0.0;
    final paid      = totalFee - _totalOutstanding;
    return _card(
      child: Column(
        children: [
          _totalsRow('TOTAL INVOICE', _fmt(totalFee), const Color(0xFF111827)),
          const Divider(height: 20),
          _totalsRow('TOTAL PAYMENT', _fmt(paid < 0 ? 0 : paid), const Color(0xFF43A047)),
          const Divider(height: 20),
          _totalsRow('SCHOLARSHIP', 'RM 0.00', const Color(0xFF1E5BFF)),
          const Divider(height: 20),
          _totalsRow('ADJUSTMENT', 'RM 0.00', const Color(0xFF5B6B86)),
        ],
      ),
    );
  }

  Widget _recentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827))),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PaymentHistoryPage(controller: widget.controller)),
              ),
              child: const Text('View All', style: TextStyle(color: Color(0xFF1E5BFF))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentPayments.isEmpty)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No recent transactions.', style: TextStyle(color: Color(0xFF5B6B86))),
          ))
        else
          ..._recentPayments.map((p) => _transactionCard(p)),
        const SizedBox(height: 8),
        if (_recentFees.isNotEmpty)
          ..._recentFees.map((f) => _feeCard(f)),
      ],
    );
  }

  Widget _transactionCard(Map<String, dynamic> p) {
    final isSuccess = p['status'] == 'Success';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check : Icons.close,
              color: isSuccess ? const Color(0xFF43A047) : const Color(0xFFE53935),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tuition Fee Payment — ${p['payment_method'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(_shortDate(p['created_at'] as String?),
                    style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt((p['amount'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSuccess ? 'SUCCESS' : 'FAILED',
                  style: TextStyle(
                    color: isSuccess ? const Color(0xFF43A047) : const Color(0xFFE53935),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feeCard(Map<String, dynamic> f) {
    final status = f['status'] as String? ?? 'Unpaid';
    final isInvoiced = status != 'Paid';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeeDetailsPage(controller: widget.controller, feeId: (f['id'] as int?) ?? 0),
        ),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF6)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Color(0xFFF1F6FF), shape: BoxShape.circle),
              child: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xFF1E5BFF), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Semester ${f['semester'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Outstanding: ${_fmt((f['outstanding_amount'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isInvoiced ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isInvoiced ? 'INVOICED' : 'PAID',
                style: TextStyle(
                  color: isInvoiced ? const Color(0xFFF57C00) : const Color(0xFF43A047),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sponsorTab() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volunteer_activism_outlined, size: 60, color: Color(0xFF5B6B86)),
          SizedBox(height: 12),
          Text('No Sponsor Linked',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
          SizedBox(height: 4),
          Text('Contact the Bursar\'s Office for sponsorship queries.',
              style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _paymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Payment',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Outstanding: ${_fmt(_totalOutstanding)}',
                    style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _totalOutstanding > 0 && _recentFees.isNotEmpty
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MakePaymentPage(
                                  controller: widget.controller,
                                  feeId: (_recentFees.first['id'] as int?) ?? 0,
                                  outstandingAmount: _totalOutstanding,
                                ),
                              ),
                            ).then((_) => _load())
                        : null,
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86), fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}
