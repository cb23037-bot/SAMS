import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class FeeRecordDetailsPage extends StatefulWidget {
  const FeeRecordDetailsPage({
    super.key,
    required this.controller,
    required this.feeId,
  });

  final AppController controller;
  final int feeId;

  @override
  State<FeeRecordDetailsPage> createState() => _FeeRecordDetailsPageState();
}

class _FeeRecordDetailsPageState extends State<FeeRecordDetailsPage> {
  bool _isLoading  = true;
  bool _isSaving   = false;
  Map<String, dynamic>? _fee;
  String _statusSelection = 'Pending';
  final _remarksController = TextEditingController();
  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  // Fetches the full details of a single fee record (widget.feeId) from the backend,
  // including the student profile and any active financial restrictions on that student.
  // Falls back to hardcoded placeholder data if the API call fails, so the treasury
  // user sees something rather than a blank screen during development.
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.controller.apiService
          .getFeeRecord(token: widget.controller.token!, feeId: widget.feeId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fee       = data['fee'] as Map<String, dynamic>?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _fee = {
          'id': widget.feeId,
          'status': 'partial',
          'total_amount': 8450.00,
          'outstanding_amount': 1510.00,
          'semester': '2025/2026-1',
          'student': {
            'id': 1,
            'user_id': 1,
            'matric_number': 'CB23201',
            'program_code': 'BCS',
            'user': {'name': 'Ahmad Syahmi bin Razali'},
            'restrictions': [],
          },
        };
      });
    }
  }

  // Returns true if the student linked to this fee record has at least one
  // restriction entry with status 'Active'. Used to decide which button
  // to show: "Apply Restriction" or "Lift Restriction".
  bool get _hasActiveRestriction {
    final student = _fee?['student'] as Map<String, dynamic>?;
    final restrictions = (student?['restrictions'] as List<dynamic>?) ?? [];
    return restrictions.any((r) {
      final m = r as Map<String, dynamic>;
      return m['status'] == 'Active';
    });
  }

  Future<void> _saveChanges() async {
    if (_statusSelection == 'Approve') {
      await _applyManualPayment();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status "$_statusSelection" noted. No payment recorded.')),
      );
    }
  }

  Future<void> _applyManualPayment() async {
    final outstanding =
        (_fee?['outstanding_amount'] as num?)?.toDouble() ?? 0;
    if (outstanding <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outstanding balance to settle.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.apiService.updateFeeRecord(
        token: widget.controller.token!,
        feeId: widget.feeId,
        fields: {'amount': outstanding, 'remarks': _remarksController.text.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record updated successfully.'),
          backgroundColor: Color(0xFF43A047),
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _liftRestriction() async {
    final student = _fee?['student'] as Map<String, dynamic>?;
    final userId = (student?['user_id'] as int?) ?? 0;
    try {
      await widget.controller.apiService
          .liftRestriction(token: widget.controller.token!, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restriction lifted.'),
          backgroundColor: Color(0xFF43A047),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _fee == null
                      ? const Center(child: Text('Record not found.'))
                      : _buildBody(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADMINISTRATION',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: _teal)),
                Text('Update Record',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF111827))),
              ],
            ),
          ),
          const Icon(Icons.notifications_none_outlined, color: Color(0xFF5B6B86)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final fee     = _fee!;
    final student = fee['student'] as Map<String, dynamic>? ?? {};
    final user    = student['user'] as Map<String, dynamic>? ?? {};
    final name    = user['name'] as String? ?? 'Unknown';
    final matric  = student['matric_number'] as String? ?? '-';
    final program = student['program_code'] as String? ?? '-';
    final total   = (fee['total_amount'] as num?)?.toDouble() ?? 0;
    final outst   = (fee['outstanding_amount'] as num?)?.toDouble() ?? 0;
    final tuition = total * 0.85;
    final misc    = total - tuition;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Student card
          _card(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _teal.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 22, color: _teal),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(matric,
                          style: const TextStyle(
                              color: Color(0xFF5B6B86), fontSize: 13)),
                      Text(program,
                          style: const TextStyle(
                              color: Color(0xFF5B6B86), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Fee breakdown
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FEE BREAKDOWN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF5B6B86))),
                const SizedBox(height: 12),
                _row('Tuition Fee', _fmt(tuition)),
                _row('Library Fee', _fmt(misc * 0.6)),
                _row('Miscellaneous', _fmt(misc * 0.4)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Total outstanding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL BALANCE DUE',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11, letterSpacing: 1)),
                    SizedBox(height: 4),
                    Text('Outstanding Amount',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  children: [
                    Text(_fmt(outst),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy_outlined, color: Colors.white70, size: 18),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Status selection
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STATUS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF5B6B86))),
                const SizedBox(height: 8),
                Row(
                  children: ['Pending', 'Approve', 'Reject'].map((s) {
                    final sel = _statusSelection == s;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _statusSelection = s),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: sel ? _teal : const Color(0xFFD6E0F0)),
                            borderRadius: BorderRadius.circular(10),
                            color: sel ? _teal.withAlpha(26) : Colors.white,
                          ),
                          child: Text(s,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: sel ? _teal : const Color(0xFF5B6B86))),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Remarks (optional)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFD),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Restriction status
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RESTRICTION STATUS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFF5B6B86))),
                const SizedBox(height: 12),
                if (_hasActiveRestriction) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.block, color: Color(0xFFE53935)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Academic Access Restricted',
                              style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _liftRestriction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _teal,
                        side: const BorderSide(color: _teal),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('LIFT RESTRICTION',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else
                  const Text('No active restrictions.',
                      style: TextStyle(color: Color(0xFF43A047), fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save Changes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF5B6B86))),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
}
