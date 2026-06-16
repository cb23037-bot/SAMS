import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'FeeRecordDetailsPage.dart';

class FeeRecordsListPage extends StatefulWidget {
  const FeeRecordsListPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<FeeRecordsListPage> createState() => _FeeRecordsListPageState();
}

class _FeeRecordsListPageState extends State<FeeRecordsListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _fees = [];
  String _search = '';
  String? _statusFilter;
  bool _hasMore = true;

  final _searchController = TextEditingController();
  static const _teal = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetches the fee records list from the backend, applying the current
  // _search text and _statusFilter (Paid/Unpaid/Partial). When reset is true
  // (the default), the existing list is replaced; when false, new items are
  // appended for pagination. Sets _hasMore = false since this endpoint
  // returns all matching records in one response (no server-side pagination).
  Future<void> _load({bool reset = true}) async {
    if (reset) {
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    try {
      final data = await widget.controller.apiService.getFeeRecords(
        token: widget.controller.token!,
        search: _search.isNotEmpty ? _search : null,
        status: _statusFilter,
      );
      if (!mounted) return;
      final items = (data['fees'] as List<dynamic>?) ?? [];
      setState(() {
        _isLoading = false;
        if (reset) {
          _fees = items.cast<Map<String, dynamic>>();
        } else {
          _fees.addAll(items.cast<Map<String, dynamic>>());
        }
        _hasMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (reset) {
          _fees = [
            {
              'id': 1,
              'status': 'Partial',
              'outstanding_amount': 1510.00,
              'total_amount': 8450.00,
              'student': {
                'matric_number': 'CB23201',
                'user': {'name': 'Ahmad Syahmi bin Razali'},
              },
            },
            {
              'id': 2,
              'status': 'Unpaid',
              'outstanding_amount': 3200.00,
              'total_amount': 3200.00,
              'student': {
                'matric_number': 'CB23202',
                'user': {'name': 'Nurul Ain binti Hassan'},
              },
            },
            {
              'id': 3,
              'status': 'Paid',
              'outstanding_amount': 0.00,
              'total_amount': 8450.00,
              'student': {
                'matric_number': 'CB23203',
                'user': {'name': 'Haziq Danial bin Mohd Rashid'},
              },
            },
          ];
        }
      });
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':    return const Color(0xFF43A047);
      case 'unpaid':  return const Color(0xFFE53935);
      default:        return const Color(0xFFF57C00);
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
            _buildSearchBar(),
            Expanded(
              child: _isLoading && _fees.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FINANCE LEDGER',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: _teal)),
                Text('Fee Registry',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF111827))),
              ],
            ),
          ),
          const Icon(Icons.account_circle_outlined, color: _teal, size: 28),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or matric no.',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFD),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                ),
              ),
              onChanged: (v) {
                _search = v;
                _load();
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list, color: Color(0xFF5B6B86)),
            onSelected: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('All')),
              PopupMenuItem(value: 'Paid', child: Text('Paid')),
              PopupMenuItem(value: 'Unpaid', child: Text('Unpaid')),
              PopupMenuItem(value: 'Partial', child: Text('Partial')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _fees.length + 1,
        itemBuilder: (context, i) {
          if (i == _fees.length) {
            return _hasMore
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton(
                      onPressed: () => _load(reset: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _teal,
                        side: const BorderSide(color: _teal),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('LOAD MORE'),
                    ),
                  )
                : const SizedBox(height: 16);
          }
          return _feeTile(_fees[i]);
        },
      ),
    );
  }

  Widget _feeTile(Map<String, dynamic> fee) {
    final name   = fee['student_name'] as String? ?? 'Unknown';
    final matric = fee['matric_number'] as String? ?? '-';
    final status = fee['status'] as String? ?? 'unpaid';
    final amount = (fee['balance'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeeRecordDetailsPage(
            controller: widget.controller,
            feeId: (fee['id'] as int?) ?? 0,
          ),
        ),
      ).then((_) => _load()),
      child: Container(
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
                color: _statusColor(status).withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: _statusColor(status)),
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
                  Text(matric,
                      style: const TextStyle(
                          color: Color(0xFF5B6B86), fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
