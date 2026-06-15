import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../services/api_service.dart';
import '../../utils/parse.dart';

class UnpaidFeesMonitorPage extends StatefulWidget {
  const UnpaidFeesMonitorPage({super.key, required this.controller, this.embedded = false});
  final AppController controller;
  final bool embedded;

  @override
  State<UnpaidFeesMonitorPage> createState() => _UnpaidFeesMonitorPageState();
}

class _UnpaidFeesMonitorPageState extends State<UnpaidFeesMonitorPage> {
  static const _teal = Color(0xFF00897B);

  bool _loading = true;
  String? _error;
  List<dynamic> _fees = [];
  final Set<int> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getUnpaidFees(
        token: widget.controller.token!,
      );
      setState(() { _fees = data['fees'] as List<dynamic>? ?? []; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _toggleRestriction(Map<String, dynamic> fee, bool isRestricted) async {
    final userId = fee['user_id'] as int;
    setState(() => _processing.add(userId));

    try {
      if (isRestricted) {
        await widget.controller.apiService.liftRestriction(
            token: widget.controller.token!, userId: userId);
      } else {
        await widget.controller.apiService.applyRestriction(
            token: widget.controller.token!, userId: userId);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : null;
      // Stale list — the restriction state already changed. Refresh silently.
      if (code == 'ALREADY_RESTRICTED') { await _load(); return; }
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('No active restriction')) { await _load(); return; }
      final isRestrictionError = code == 'RESTRICTION_ERROR';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRestrictionError
            ? 'Could not update restriction. Please try again.'
            : e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: const Color(0xFFDC2626),
        action: isRestrictionError
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _toggleRestriction(fee, isRestricted),
              )
            : null,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: _teal))
        : _error != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load,
                    style: FilledButton.styleFrom(backgroundColor: _teal), child: const Text('Retry')),
              ]))
            : _fees.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
                    SizedBox(height: 12),
                    Text('All fees are paid!', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _teal,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _fees.length,
                      itemBuilder: (_, i) {
                        final fee = _fees[i] as Map<String, dynamic>;
                        final isRestricted = fee['is_restricted'] == true;
                        final userId = fee['user_id'] as int;
                        final processing = _processing.contains(userId);
                        return _UnpaidFeeCard(
                          fee: fee,
                          isRestricted: isRestricted,
                          processing: processing,
                          onToggle: () => _toggleRestriction(fee, isRestricted),
                        );
                      },
                    ),
                  );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF111827)),
        title: const Text('Unpaid Fees',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827), fontSize: 18)),
      ),
      body: body,
    );
  }
}

class _UnpaidFeeCard extends StatelessWidget {
  const _UnpaidFeeCard({
    required this.fee,
    required this.isRestricted,
    required this.processing,
    required this.onToggle,
  });
  final Map<String, dynamic> fee;
  final bool isRestricted, processing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final status = fee['status'] as String;
    final (statusLabel, statusBg, statusFg) = status == 'partial'
        ? ('Partial', const Color(0xFFFEF3C7), const Color(0xFFD97706))
        : ('Unpaid',  const Color(0xFFFFEBEE), const Color(0xFFDC2626));

    final feeCount   = fee['fee_count'] as int? ?? 1;
    final semesters  = (fee['semesters'] as List?)?.cast<String>() ?? [];
    final semLabel   = semesters.length == 1
        ? semesters.first
        : '${semesters.length} semesters';
    final feesSuffix = feeCount > 1 ? ' • $feeCount fees' : '';
    final subtitle   = '${fee['matric_number']} • $semLabel$feesSuffix';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isRestricted ? Border.all(color: const Color(0xFFEF9A9A), width: 1.5) : null,
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fee['student_name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel,
                style: TextStyle(color: statusFg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _AmtChip(label: 'Balance', value: parseDouble(fee['total_balance']), red: true),
          const SizedBox(width: 16),
          _AmtChip(label: 'Total', value: parseDouble(fee['total_amount']), red: false),
          const SizedBox(width: 16),
          _AmtChip(label: 'Paid', value: parseDouble(fee['total_paid']), red: false),
        ]),
        const SizedBox(height: 10),
        Text('Due: ${fee['earliest_due'] ?? '-'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 12),
        Row(children: [
          if (isRestricted)
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, color: Color(0xFFDC2626), size: 14),
                SizedBox(width: 4),
                Text('Restricted', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ))
          else
            const Spacer(),
          const SizedBox(width: 10),
          processing
              ? const SizedBox(width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00897B)))
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isRestricted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    side: BorderSide(color: isRestricted ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onToggle,
                  icon: Icon(isRestricted ? Icons.lock_open_outlined : Icons.lock_outline, size: 16),
                  label: Text(isRestricted ? 'Lift' : 'Restrict',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
        ]),
      ]),
    );
  }
}

class _AmtChip extends StatelessWidget {
  const _AmtChip({required this.label, required this.value, required this.red});
  final String label;
  final double value;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      Text('RM ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: red && value > 0 ? const Color(0xFFDC2626) : const Color(0xFF111827),
          )),
    ]);
  }
}
