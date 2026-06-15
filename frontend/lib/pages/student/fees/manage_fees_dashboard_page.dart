import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../utils/parse.dart';
import '../notifications_page.dart';
import 'fee_details_page.dart';
import 'make_payment_page.dart';
import 'payment_receipt_page.dart';

class ManageFeesDashboardPage extends StatefulWidget {
  const ManageFeesDashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ManageFeesDashboardPage> createState() => _ManageFeesDashboardPageState();
}

class _ManageFeesDashboardPageState extends State<ManageFeesDashboardPage>
    with SingleTickerProviderStateMixin {
  static const _blue   = Color(0xFF1565C0);
  static const _blue2  = Color(0xFF1976D2);

  late final TabController _tab;

  // Fees + restriction
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _feesData;
  bool _restricted = false;
  int? _currentWeek;

  // Sponsor
  List<dynamic> _sponsors = [];

  // Notifications
  int _unreadCount = 0;
  bool _hasRestrictionNotif = false;

  // Ledger (lazy)
  bool _ledgerLoading = false;
  bool _ledgerLoaded  = false;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 2 && !_ledgerLoaded && !_ledgerLoading) {
        _loadLedger();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.controller.apiService.getStudentFees(token: widget.controller.token!),
        widget.controller.apiService.getRestrictionStatus(token: widget.controller.token!),
        widget.controller.apiService.getStudentSponsors(token: widget.controller.token!),
        widget.controller.apiService.getNotifications(token: widget.controller.token!),
      ]);
      final notifs = (results[3]['notifications'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _feesData    = results[0];
        _restricted  = results[1]['restricted'] == true;
        _currentWeek = results[1]['current_week'] as int?;
        _sponsors    = (results[2]['sponsors'] as List?) ?? [];
        _unreadCount        = notifs.where((n) => n['is_read'] == false).length;
        _hasRestrictionNotif = notifs.any(
          (n) => n['type'] == 'restriction' && n['is_read'] == false,
        );
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _loadLedger() async {
    setState(() => _ledgerLoading = true);
    try {
      final data = await widget.controller.apiService.getStudentLedger(
        token: widget.controller.token!,
      );
      setState(() {
        _transactions = (data['transactions'] as List?) ?? [];
        _ledgerLoaded  = true;
        _ledgerLoading = false;
      });
    } catch (_) {
      setState(() => _ledgerLoading = false);
    }
  }

  // All unpaid/partial fees
  List<Map<String, dynamic>> get _unpaidFees {
    final fees = (_feesData?['fees'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return fees.where((f) => f['status'] != 'paid').toList();
  }

  // Earliest unpaid due date
  String get _deadline {
    final unpaid = _unpaidFees;
    if (unpaid.isEmpty) return '-';
    unpaid.sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));
    final raw = unpaid.first['due_date'] as String;
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  void _goPayNow() {
    final unpaid = _unpaidFees;
    if (unpaid.isEmpty) return;

    if (unpaid.length == 1) {
      _navigateToPayment(unpaid.first);
      return;
    }

    // Multiple unpaid fees — show selection sheet
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _FeeSelectionSheet(
        fees: unpaid,
        onSelect: (fee) {
          Navigator.of(context).pop();
          _navigateToPayment(fee);
        },
      ),
    );
  }

  void _navigateToPayment(Map<String, dynamic> fee) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MakePaymentPage(
        controller: widget.controller,
        feeId: fee['id'] as int,
        balance: parseDouble(fee['balance']),
        description: fee['description'] as String,
      ),
    )).then((_) => _load());
  }

  void _goViewDetails() {
    final allFees = (_feesData?['fees'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (allFees.isEmpty) return;
    if (allFees.length == 1) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FeeDetailsPage(
          controller: widget.controller,
          feeId: allFees.first['id'] as int,
        ),
      )).then((_) => _load());
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9FAFB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _FeeDetailsSelectionSheet(
        fees: allFees,
        onSelect: (fee) {
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FeeDetailsPage(
              controller: widget.controller,
              feeId: fee['id'] as int,
            ),
          )).then((_) => _load());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;
    final summary = _feesData?['summary'] as Map<String, dynamic>? ?? {};
    final total   = parseDouble(summary['total']);
    final paid    = parseDouble(summary['paid']);
    final unpaid  = parseDouble(summary['unpaid']);

    // Compute how much of the sponsor coverage is still available.
    // Once the student has paid 'paid' in total, the sponsor is considered
    // used up proportionally — prevents double-counting after a fee is settled.
    final activeSponsorTotal = _sponsors
        .cast<Map<String, dynamic>>()
        .where((s) => s['status'] == 'active' && parseDouble(s['amount']) > 0)
        .fold<double>(0.0, (sum, s) => sum + parseDouble(s['amount']));
    final effectiveSponsor = (activeSponsorTotal - paid).clamp(0.0, activeSponsorTotal);
    final netUnpaid = (unpaid - effectiveSponsor).clamp(0.0, double.infinity);

    final hasOutstanding = _unpaidFees.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Manage Fees',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => NotificationsPage(controller: widget.controller),
                )).then((_) => _load()),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    // ── GAP 2: Restriction alert card ─────────────────────
                    if (_hasRestrictionNotif)
                      _RestrictionAlert(onPayNow: _goPayNow),

                    // ── Blue hero section ─────────────────────────────────
                    _HeroSection(
                      total: total,
                      paid: paid,
                      unpaid: netUnpaid,
                      deadline: _deadline,
                      hasOutstanding: hasOutstanding,
                      courseName: user.course ?? 'Bachelor of Computer Science',
                      studentId: user.studentId ?? '-',
                      semester: user.currentSemester ?? '-',
                      onPayNow: hasOutstanding ? _goPayNow : null,
                    ),

                    // ── Tab bar ───────────────────────────────────────────
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tab,
                        labelColor: _blue,
                        unselectedLabelColor: const Color(0xFF9CA3AF),
                        indicatorColor: _blue,
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                        tabs: const [
                          Tab(text: 'Summary'),
                          Tab(text: 'Sponsor'),
                          Tab(text: 'History'),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),

                    // ── Tab content ───────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _SummaryTab(
                            feesData: _feesData!,
                            sponsors: _sponsors,
                            unpaid: netUnpaid,
                            effectiveSponsor: effectiveSponsor,
                            activeSponsorTotal: activeSponsorTotal,
                            onViewDetails: _goViewDetails,
                          ),
                          _SponsorTab(
                            sponsors: _sponsors,
                            effectiveSponsor: effectiveSponsor,
                            activeSponsorTotal: activeSponsorTotal,
                          ),
                          _HistoryTab(
                            loading: _ledgerLoading,
                            transactions: _transactions,
                            controller: widget.controller,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.total,
    required this.paid,
    required this.unpaid,
    required this.deadline,
    required this.hasOutstanding,
    required this.courseName,
    required this.studentId,
    required this.semester,
    required this.onPayNow,
  });

  final double total, paid, unpaid;
  final String deadline, courseName, studentId, semester;
  final bool hasOutstanding;
  final VoidCallback? onPayNow;

  String _fmt(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RM $whole.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outstanding Balance label + Due badge
          Row(children: [
            const Text('Outstanding Balance',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            if (hasOutstanding)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.access_time_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Due', style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
          const SizedBox(height: 6),

          // Amount
          Text(_fmt(unpaid),
              style: const TextStyle(
                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 3),
          if (hasOutstanding)
            Text('Deadline: $deadline',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 0.5),
          const SizedBox(height: 12),

          // Total Invoice / Total Payment
          Row(children: [
            _HeroStat(label: 'Total Invoice',  value: _fmt(total)),
            const SizedBox(width: 32),
            _HeroStat(label: 'Total Payment',  value: _fmt(paid)),
          ]),
          const SizedBox(height: 16),

          // Student info chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.school_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(courseName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$studentId · $semester · UMPSA',
                      style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 14),

          // Pay Now button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onPayNow,
              child: Text(
                onPayNow != null ? 'Pay Now  →' : 'All Fees Settled',
                style: TextStyle(
                  color: onPayNow != null ? const Color(0xFF1565C0) : const Color(0xFF16A34A),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Summary Tab ───────────────────────────────────────────────────────────────

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.feesData,
    required this.sponsors,
    required this.unpaid,
    required this.effectiveSponsor,
    required this.activeSponsorTotal,
    required this.onViewDetails,
  });
  final Map<String, dynamic> feesData;
  final List<dynamic> sponsors;
  final double unpaid, effectiveSponsor, activeSponsorTotal;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final fees = (feesData['fees'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final activeSponsors = sponsors
        .cast<Map<String, dynamic>>()
        .where((s) => s['status'] == 'active' && parseDouble(s['amount']) > 0)
        .toList();

    // Only show fees that still have an outstanding balance.
    final unpaidFees = fees
        .where((f) => f['status'] != 'paid' && parseDouble(f['balance']) > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Fee line items — use balance (what's left), not the full amount.
        ...unpaidFees.map((f) => _SummaryRow(
          label: f['description'] as String,
          amount: parseDouble(f['balance']),
        )),

        // Sponsor deductions — show only the remaining (unused) coverage.
        // Each sponsor's effective share is proportional to its original amount.
        ...activeSponsors
            .map((s) {
              final sOriginal = parseDouble(s['amount']);
              final sEffective = activeSponsorTotal > 0
                  ? (sOriginal / activeSponsorTotal) * effectiveSponsor
                  : 0.0;
              return (sponsor: s, effective: sEffective);
            })
            .where((r) => r.effective > 0.001)
            .map((r) => _SummaryRow(
              label: '${r.sponsor['name']} (${_typeLabel(r.sponsor['type'] as String)})',
              amount: -r.effective,
              green: true,
            )),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Color(0xFFE5E7EB)),
        ),

        // Outstanding balance
        Row(children: [
          const Expanded(
            child: Text('Outstanding Balance',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                    color: Color(0xFF111827))),
          ),
          Text(_fmt(unpaid),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: unpaid > 0 ? const Color(0xFFE53935) : const Color(0xFF16A34A),
              )),
        ]),
        const SizedBox(height: 24),

        // View Fee Details button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1565C0),
            side: const BorderSide(color: Color(0xFF1565C0)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onViewDetails,
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('View Fee Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),

        const SizedBox(height: 16),
        const Text('Fee information sourced from Finance Division.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }

  String _typeLabel(String type) => switch (type) {
    'scholarship' => 'Scholarship',
    'loan'        => 'Loan',
    'bursary'     => 'Bursary',
    'grant'       => 'Grant',
    _             => type,
  };

  String _fmt(double v) {
    final parts = v.abs().toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RM $whole.${parts[1]}';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.amount, this.green = false});
  final String label;
  final double amount;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final isNegative = amount < 0;
    final display = isNegative
        ? '- RM ${amount.abs().toStringAsFixed(2)}'
        : 'RM ${amount.toStringAsFixed(2)}';
    final color = green
        ? const Color(0xFF16A34A)
        : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)))),
        Text(display,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── Sponsor Tab ───────────────────────────────────────────────────────────────

class _SponsorTab extends StatelessWidget {
  const _SponsorTab({
    required this.sponsors,
    required this.effectiveSponsor,
    required this.activeSponsorTotal,
  });
  final List<dynamic> sponsors;
  final double effectiveSponsor, activeSponsorTotal;

  @override
  Widget build(BuildContext context) {
    if (sponsors.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.account_balance_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('No sponsor records found.',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        ...sponsors.cast<Map<String, dynamic>>().map((s) {
          final sOriginal = parseDouble(s['amount']);
          final sEffective = s['status'] == 'active' && activeSponsorTotal > 0
              ? (sOriginal / activeSponsorTotal) * effectiveSponsor
              : sOriginal;
          return _SponsorCard(sponsor: s, remaining: sEffective);
        }),
        const SizedBox(height: 8),
        const Text('Scholarship data sourced from Finance Division.',
            style: TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 11,
                fontStyle: FontStyle.italic),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _SponsorCard extends StatelessWidget {
  const _SponsorCard({required this.sponsor, required this.remaining});
  final Map<String, dynamic> sponsor;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final status   = sponsor['status'] as String;
    final amount   = parseDouble(sponsor['amount']);
    final type     = sponsor['type'] as String;
    final coverage = sponsor['coverage'] as String?;

    // If the sponsor is active but all coverage has been used, show as depleted.
    final isActive   = status == 'active';
    final isDepleted = isActive && amount > 0 && remaining < 0.01;
    final used       = isActive ? (amount - remaining).clamp(0.0, amount) : 0.0;

    final (statusLabel, statusBg, statusFg) = isDepleted
        ? ('Depleted',    const Color(0xFFFEF3C7), const Color(0xFFD97706))
        : switch (status) {
            'active'   => ('Active',      const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
            'inactive' => ('Inactive',    const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
            _          => ('Not Applied', const Color(0xFFF3F4F6), const Color(0xFF9CA3AF)),
          };

    final typeLabel = switch (type) {
      'scholarship' => 'Scholarship',
      'loan'        => 'Loan',
      'bursary'     => 'Bursary',
      'grant'       => 'Grant',
      _             => type,
    };

    final coverageText = coverage != null ? '$typeLabel · $coverage' : typeLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(sponsor['name'] as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusFg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(coverageText,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        // Show remaining prominently; show used breakdown only for active sponsors.
        Text('RM ${remaining.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800,
                color: isDepleted ? const Color(0xFFD97706) : const Color(0xFF1565C0))),
        if (isActive && amount > 0) ...[
          const SizedBox(height: 6),
          Row(children: [
            _AmountPill(label: 'Allocated', value: amount, blue: true),
            const SizedBox(width: 10),
            if (used > 0) _AmountPill(label: 'Used', value: used, blue: false),
          ]),
        ],
      ]),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill({required this.label, required this.value, required this.blue});
  final String label;
  final double value;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: blue ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: RM ${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: blue ? const Color(0xFF1565C0) : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.loading,
    required this.transactions,
    required this.controller,
  });
  final bool loading;
  final List<dynamic> transactions;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }
    if (transactions.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('No transactions yet.', style: TextStyle(color: Color(0xFF9CA3AF))),
        ]),
      );
    }

    // Only show actual payment transactions — sponsors are not bank history.
    final payments = transactions
        .cast<Map<String, dynamic>>()
        .where((t) => t['type'] == 'payment')
        .toList();

    if (payments.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text('No payments yet.', style: TextStyle(color: Color(0xFF9CA3AF))),
        ]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: payments.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
      itemBuilder: (_, i) {
        final txn     = payments[i];
        final amount  = parseDouble(txn['amount']).abs();
        final dateStr = _formatDate(txn['date'] as String? ?? '');
        final txnId   = txn['id'] as String? ?? '';
        final paymentId = int.tryParse(txnId.replaceFirst('pay-', ''));

        return InkWell(
          onTap: paymentId == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PaymentReceiptPage(
                      controller: controller,
                      paymentId: paymentId,
                    ),
                  )),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn['description'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 3),
                  Text('$dateStr · ${txn['reference']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              )),
              const SizedBox(width: 12),
              Text('- RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFFE53935))),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 18),
            ]),
          ),
        );
      },
    );
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Fee Selection Sheet ───────────────────────────────────────────────────────

class _FeeSelectionSheet extends StatelessWidget {
  const _FeeSelectionSheet({required this.fees, required this.onSelect});
  final List<Map<String, dynamic>> fees;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Fee to Pay',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Choose which outstanding fee you want to settle.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
            ),
          ]),
          const SizedBox(height: 16),
          ...fees.map((fee) {
            final balance = parseDouble(fee['balance']);
            final status  = fee['status'] as String;
            final (badgeBg, badgeFg) = status == 'partial'
                ? (const Color(0xFFFEF3C7), const Color(0xFFD97706))
                : (const Color(0xFFFFEBEE), const Color(0xFFDC2626));
            final badgeLabel = status == 'partial' ? 'Partial' : 'Unpaid';

            return GestureDetector(
              onTap: () => onSelect(fee),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_outlined,
                        color: Color(0xFF1565C0), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fee['description'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(fee['semester'] as String,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  )),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('RM ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15,
                            color: Color(0xFF1565C0))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(badgeLabel,
                          style: TextStyle(color: badgeFg, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Fee Details Selection Sheet ───────────────────────────────────────────────

class _FeeDetailsSelectionSheet extends StatelessWidget {
  const _FeeDetailsSelectionSheet({required this.fees, required this.onSelect});
  final List<Map<String, dynamic>> fees;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Fee to View',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Choose a fee to see its full details and payment history.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
            ),
          ]),
          const SizedBox(height: 16),
          ...fees.map((fee) {
            final balance = parseDouble(fee['balance']);
            final status  = fee['status'] as String;
            final (badgeBg, badgeFg, badgeLabel) = switch (status) {
              'paid'    => (const Color(0xFFDCFCE7), const Color(0xFF16A34A), 'Paid'),
              'partial' => (const Color(0xFFFEF3C7), const Color(0xFFD97706), 'Partial'),
              _         => (const Color(0xFFFFEBEE), const Color(0xFFDC2626), 'Unpaid'),
            };

            return GestureDetector(
              onTap: () => onSelect(fee),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: Color(0xFF1565C0), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fee['description'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(fee['semester'] as String,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  )),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('RM ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15,
                            color: Color(0xFF1565C0))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(badgeLabel,
                          style: TextStyle(color: badgeFg, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB), size: 20),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

// ── GAP 2: Restriction Alert Card ────────────────────────────────────────────

class _RestrictionAlert extends StatelessWidget {
  const _RestrictionAlert({required this.onPayNow});
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPayNow,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFFDC2626),
        child: Row(children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Academic Access Restricted',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 13)),
              SizedBox(height: 2),
              Text('Tap to view details and make payment',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
        ]),
      ),
    );
  }
}

// ── GAP 4: Full-screen error widget ──────────────────────────────────────────

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
          const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          const Text('Unable to load data.',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16,
                  color: Color(0xFF111827))),
          const SizedBox(height: 8),
          Text(
            message.contains('DB_ERROR')
                ? 'Please check your connection and try again.'
                : message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }
}
