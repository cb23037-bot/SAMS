import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class UnpaidFeesMonitorPage extends StatefulWidget {
  const UnpaidFeesMonitorPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<UnpaidFeesMonitorPage> createState() => _UnpaidFeesMonitorPageState();
}

class _UnpaidFeesMonitorPageState extends State<UnpaidFeesMonitorPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fees = [];
  bool _showAll = false;

  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.controller.apiService
          .getUnpaidFees(token: widget.controller.token!);
      if (!mounted) return;
      final list = (data['fees'] as List<dynamic>?) ?? [];
      setState(() {
        _isLoading = false;
        _fees      = list.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fees = [
          {
            'student_id': 2,
            'user_id': 2,
            'student_name': 'Nurul Ain binti Hassan',
            'matric_number': 'CB23202',
            'status': 'unpaid',
            'total_balance': 3200.00,
            'total_amount': 3200.00,
            'total_paid': 0.00,
            'is_restricted': false,
          },
          {
            'student_id': 1,
            'user_id': 1,
            'student_name': 'Ahmad Syahmi bin Razali',
            'matric_number': 'CB23201',
            'status': 'partial',
            'total_balance': 1510.00,
            'total_amount': 8450.00,
            'total_paid': 6940.00,
            'is_restricted': false,
          },
        ];
      });
    }
  }

  Future<void> _restrict(Map<String, dynamic> fee) async {
    final userId = (fee['user_id'] as int?) ?? 0;
    final name   = fee['student_name'] as String? ?? 'this student';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restriction'),
        content: Text('Apply financial bar to $name? This will restrict academic access.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Restrict', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.controller.apiService
          .applyRestriction(token: widget.controller.token!, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restriction applied to $name.'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  String _fmt(double v) => 'RM ${v.toStringAsFixed(2)}';

  double get _totalOutstanding =>
      _fees.fold(0.0, (s, f) => s + ((f['total_balance'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    final visible = _showAll ? _fees : _fees.take(5).toList();
    final hidden  = _fees.length - visible.length;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _enforcementCard(),
                            const SizedBox(height: 14),
                            _policyBox(),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('OVERDUE STUDENT LIST',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFF5B6B86))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Text('SORTED BY AMOUNT',
                                      style: TextStyle(
                                          color: Color(0xFF43A047),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_fees.isEmpty)
                              const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No overdue students.',
                                    style: TextStyle(color: Color(0xFF5B6B86))),
                              ))
                            else ...[
                              ...visible.map((f) => _studentCard(f)),
                              if (hidden > 0)
                                TextButton(
                                  onPressed: () => setState(() => _showAll = true),
                                  child: Text('View $hidden More Students',
                                      style: const TextStyle(color: _teal)),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Financial Risk Assessment',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF111827))),
          ),
          const Icon(Icons.language_outlined, color: Color(0xFF5B6B86)),
        ],
      ),
    );
  }

  Widget _enforcementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WEEK 5 RULE ENFORCEMENT',
              style: TextStyle(
                  color: Colors.white70, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            'Overdue Amount ${_fmt(_totalOutstanding)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fees.length} Student${_fees.length == 1 ? '' : 's'} Affected',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _policyBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Per Section 4.2 of the Academic Charter: Students with outstanding fees after Week 5 are subject to academic restrictions until full payment or approved deferment.',
              style: TextStyle(color: Color(0xFFF57C00), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> fee) {
    final name   = fee['student_name'] as String? ?? 'Unknown';
    final matric = fee['matric_number'] as String? ?? '-';
    final amount = (fee['total_balance'] as num?)?.toDouble() ?? 0;
    final status = fee['status'] as String? ?? 'unpaid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Color(0xFFE53935)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Row(
                  children: [
                    Text(matric,
                        style: const TextStyle(
                            color: Color(0xFF5B6B86), fontSize: 12)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(status.toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text(_fmt(amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFFE53935))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _restrict(fee),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            child: const Text('RESTRICT\nACCESS', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
