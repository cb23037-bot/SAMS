import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/app_controller.dart';

// ── Internal models ───────────────────────────────────────────────────────────
// These are lightweight, file-private models used only to display data fetched
// from the Pusat Adab "claims overview" and "activity claims" endpoints. They
// intentionally mirror only the fields the UI needs (not full backend models).

/// Aggregate counts of credit claims across the whole system (overview screen).
class _Stats {
  const _Stats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });
  final int total, pending, approved, rejected;
}

/// A single activity row on the overview screen, with its claim counts.
/// Tapping "View Claims" on this card drills into [_buildActivityView].
class _ClaimActivity {
  const _ClaimActivity({
    required this.id,
    required this.name,
    required this.code,
    this.location,
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });
  final int id;
  final String name, code;
  final String? location;
  final int total, pending, approved, rejected;
}

/// Minimal student info embedded inside a [_CreditClaim].
class _Student {
  const _Student({
    required this.id,
    required this.name,
    this.studentId,
    this.course,
    required this.email,
  });
  final int id;
  final String name, email;
  final String? studentId, course;
}

/// Minimal activity info embedded inside a [_CreditClaim].
/// [cats] defaults to 2 to match the backend's default CATs award value.
class _ActivityInfo {
  const _ActivityInfo({
    required this.id,
    required this.name,
    required this.code,
    this.location,
    this.cats = 2,
  });
  final int id;
  final String name, code;
  final String? location;
  final int cats;
}

/// Minimal slot info (date/time) embedded inside a [_CreditClaim].
class _SlotInfo {
  const _SlotInfo({required this.id, required this.date, required this.time});
  final int id;
  final String date, time;
}

/// A single student credit claim as shown on the activity claims table and
/// the claim detail dialog.
///
/// [status] mirrors the registration's `claim_status` and drives most of the
/// UI logic in this file: 'pending' | 'claimed' (approved) | 'rejected'.
class _CreditClaim {
  const _CreditClaim({
    required this.id,
    required this.status,
    this.proofPath,
    this.remarks,
    this.rejectionReason,
    required this.student,
    required this.activity,
    required this.slot,
  });
  final int id;
  final String status;

  /// Server-side relative path to the uploaded proof document (if any).
  /// Used to download/view the PDF via [ApiService.downloadProof].
  final String? proofPath, remarks, rejectionReason;
  final _Student student;
  final _ActivityInfo activity;
  final _SlotInfo slot;

  // ── Status helpers ─────────────────────────────────────────────────────────
  /// True while Pusat Adab has not yet approved/rejected this claim.
  bool get isPending  => status == 'pending';
  /// True once Pusat Adab has approved ("claimed") this claim.
  bool get isApproved => status == 'claimed';
  /// True once Pusat Adab has rejected this claim.
  bool get isRejected => status == 'rejected';

  /// Deserializes a claim (with nested student/activity/slot) from the JSON
  /// returned by the `getActivityClaims` / `getClaimsOverview` endpoints.
  factory _CreditClaim.fromJson(Map<String, dynamic> j) {
    final s  = j['student']  as Map<String, dynamic>;
    final a  = j['activity'] as Map<String, dynamic>;
    final sl = j['slot']     as Map<String, dynamic>;
    return _CreditClaim(
      id:              (j['id'] as num).toInt(),
      status:          j['claim_status'] as String,
      proofPath:       j['proof_path']       as String?,
      remarks:         j['remarks']          as String?,
      rejectionReason: j['rejection_reason'] as String?,
      student: _Student(
        id:        (s['id'] as num).toInt(),
        name:      s['name']       as String,
        studentId: s['student_id'] as String?,
        course:    s['course']     as String?,
        email:     s['email']      as String,
      ),
      activity: _ActivityInfo(
        id:       (a['id'] as num).toInt(),
        name:     a['name']     as String,
        code:     a['code']     as String,
        location: a['location'] as String?,
        cats:     (a['cats'] as num?)?.toInt() ?? 2,
      ),
      slot: _SlotInfo(
        id:   (sl['id'] as num).toInt(),
        date: sl['date'] as String,
        time: sl['time'] as String,
      ),
    );
  }
}

/// The action chosen from [_ClaimDetailDialog] when it is closed —
/// determines whether [_ManageClaimsPageState] opens the approve or
/// reject follow-up dialog.
enum _DetailAction { approve, reject }

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats an ISO date string (e.g. "2025-06-14") as "Jun 14, 2025"
/// for display in claim rows and detail dialogs.
String _fmtDate(String dateStr) {
  final d = DateTime.parse(dateStr);
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main page
// ═══════════════════════════════════════════════════════════════════════════════

/// Pusat Adab's "Manage Credit Claims" page.
///
/// Has two screens managed via [_selectedActivity]:
///  1. Overview — lists every activity that has at least one credit claim,
///     with aggregate stats (total/pending/approved/rejected) and a search bar.
///  2. Activity view — drills into one activity's claims, with filter tabs
///     (All/Pending/Approved/Rejected), a student search box, and a table
///     of claims. Tapping a row opens [_ClaimDetailDialog].
///
/// Can also be opened directly from a notification via [initialActivityId]
/// and [initialClaimId], which skips straight to the activity view and pops
/// open the relevant claim's detail dialog.
class ManageClaimsPage extends StatefulWidget {
  const ManageClaimsPage({
    super.key,
    required this.controller,
    this.initialActivityId,
    this.initialClaimId,
  });
  final AppController controller;

  /// When set (e.g. opened from a notification), the page drills straight
  /// into this activity's claims on load.
  final int? initialActivityId;

  /// When set alongside [initialActivityId], the matching claim's detail
  /// dialog is opened automatically once the claims have loaded.
  final int? initialClaimId;

  @override
  State<ManageClaimsPage> createState() => _ManageClaimsPageState();
}

class _ManageClaimsPageState extends State<ManageClaimsPage> {
  // ── Overview state ──────────────────────────────────────────────────────────
  /// Global claim counts across all activities (fetched once on load).
  _Stats? _globalStats;
  /// Full list of activities with claims, as returned by the API.
  List<_ClaimActivity> _activities   = [];
  /// Subset of [_activities] matching the current search query.
  /// This is what is actually rendered in the overview list.
  List<_ClaimActivity> _filteredActs = [];
  /// True while [_loadOverview] is fetching data.
  bool    _loading = true;
  /// Error message (if any) from the last [_loadOverview] call.
  String? _error;
  final _searchCtrl = TextEditingController();

  // ── Activity drill-down state ───────────────────────────────────────────────
  /// The activity currently being viewed in detail, or null if on the
  /// overview screen. Controls which screen [build] renders.
  _ClaimActivity? _selectedActivity;
  /// All claims for [_selectedActivity], as returned by the API.
  List<_CreditClaim> _claims     = [];
  /// True while claims for the selected activity are loading/refreshing.
  bool    _claimsLoading = false;
  /// Error message (if any) from the last claims fetch.
  String? _claimsError;
  /// Currently selected status filter tab: 0=All 1=Pending 2=Approved 3=Rejected.
  int     _filterIndex = 0;         // 0=All 1=Pending 2=Approved 3=Rejected
  final _studentSearchCtrl = TextEditingController();
  /// Current student name/ID search text within the selected activity.
  String  _studentQuery    = '';

  @override
  void initState() {
    super.initState();
    // Re-filter the activity list whenever the search box changes.
    _searchCtrl.addListener(() => _applySearch(_searchCtrl.text));
    // Re-filter the claims table whenever the student search box changes.
    _studentSearchCtrl.addListener(
      () => setState(() => _studentQuery = _studentSearchCtrl.text),
    );
    // If opened from a notification, jump straight into the relevant
    // activity/claim instead of showing the overview first.
    if (widget.initialActivityId != null) {
      _openFromNotification();
    } else {
      _loadOverview();
    }
  }

  // Opened from a notification — loads the overview, drills into the
  // referenced activity, then opens the detail dialog for the tapped claim.
  Future<void> _openFromNotification() async {
    await _loadOverview();
    if (!mounted) return;

    _ClaimActivity? activity;
    for (final a in _activities) {
      if (a.id == widget.initialActivityId) {
        activity = a;
        break;
      }
    }
    if (activity == null) return;

    await _selectActivity(activity);
    if (!mounted) return;

    final claimId = widget.initialClaimId;
    if (claimId == null) return;
    _CreditClaim? claim;
    for (final c in _claims) {
      if (c.id == claimId) {
        claim = c;
        break;
      }
    }
    if (claim == null) return;

    _openClaimDetail(claim);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  /// Fetches the global claim stats and the list of activities with claims
  /// from `getClaimsOverview`. Populates [_globalStats], [_activities] and
  /// [_filteredActs], then re-applies the current search filter.
  Future<void> _loadOverview() async {
    setState(() { _loading = true; _error = null; });
    try {
      final json = await widget.controller.apiService.getClaimsOverview(
        token: widget.controller.token!,
      );
      final s    = json['stats'] as Map<String, dynamic>;
      final acts = (json['activities'] as List<dynamic>)
          .map((a) => _parseActivity(a as Map<String, dynamic>))
          .toList();
      setState(() {
        _globalStats = _Stats(
          total:    (s['total']    as num).toInt(),
          pending:  (s['pending']  as num).toInt(),
          approved: (s['approved'] as num).toInt(),
          rejected: (s['rejected'] as num).toInt(),
        );
        _activities   = acts;
        _filteredActs = acts;
      });
      _applySearch(_searchCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Maps a raw activity JSON object (with `claims_*` count fields) to a
  /// [_ClaimActivity].
  _ClaimActivity _parseActivity(Map<String, dynamic> j) => _ClaimActivity(
    id:       (j['id'] as num).toInt(),
    name:     j['name']     as String,
    code:     j['code']     as String,
    location: j['location'] as String?,
    total:    (j['claims_total']    as num).toInt(),
    pending:  (j['claims_pending']  as num).toInt(),
    approved: (j['claims_approved'] as num).toInt(),
    rejected: (j['claims_rejected'] as num).toInt(),
  );

  /// Filters [_activities] by [q] (matching name or code, case-insensitive)
  /// into [_filteredActs] for display on the overview screen.
  void _applySearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filteredActs = _activities.where((a) =>
          a.name.toLowerCase().contains(lower) ||
          a.code.toLowerCase().contains(lower)).toList();
    });
  }

  /// Drills into [activity]: switches the page to the activity view and
  /// fetches its claims via `getActivityClaims`. Resets the filter tab and
  /// student search before loading.
  Future<void> _selectActivity(_ClaimActivity activity) async {
    setState(() {
      _selectedActivity = activity;
      _claims       = [];
      _claimsLoading = true;
      _claimsError   = null;
      _filterIndex = 0;
      _studentQuery = '';
      _studentSearchCtrl.clear();
    });
    try {
      final json = await widget.controller.apiService.getActivityClaims(
        token:      widget.controller.token!,
        activityId: activity.id,
      );
      setState(() {
        _claims = (json['claims'] as List<dynamic>)
            .map((c) => _CreditClaim.fromJson(c as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      setState(() => _claimsError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _claimsLoading = false);
    }
  }

  /// Re-fetches claims for [_selectedActivity] without resetting filters —
  /// used after pull-to-refresh and after approve/reject actions so the
  /// table reflects the latest status. Failures are swallowed since this
  /// runs silently in the background.
  Future<void> _refreshClaims() async {
    if (_selectedActivity == null) return;
    setState(() => _claimsLoading = true);
    try {
      final json = await widget.controller.apiService.getActivityClaims(
        token:      widget.controller.token!,
        activityId: _selectedActivity!.id,
      );
      setState(() {
        _claims = (json['claims'] as List<dynamic>)
            .map((c) => _CreditClaim.fromJson(c as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {
      // silently fail on background refresh
    } finally {
      setState(() => _claimsLoading = false);
    }
  }

  /// Returns from the activity view back to the overview screen, clearing
  /// drill-down state and reloading the overview stats/list.
  void _goBack() {
    setState(() {
      _selectedActivity = null;
      _claims           = [];
      _claimsError      = null;
    });
    _loadOverview();
  }

  // ── Filtered claims for current tab ─────────────────────────────────────────

  /// Claims to display in the activity table: first filtered by
  /// [_filterIndex] (status tab), then by [_studentQuery] (name/student ID).
  List<_CreditClaim> get _visibleClaims {
    final base = switch (_filterIndex) {
      1 => _claims.where((c) => c.isPending).toList(),
      2 => _claims.where((c) => c.isApproved).toList(),
      3 => _claims.where((c) => c.isRejected).toList(),
      _ => List<_CreditClaim>.from(_claims),
    };
    if (_studentQuery.isEmpty) return base;
    final q = _studentQuery.toLowerCase();
    return base.where((c) =>
      c.student.name.toLowerCase().contains(q) ||
      (c.student.studentId?.toLowerCase().contains(q) ?? false),
    ).toList();
  }

  /// Recomputes total/pending/approved/rejected counts from the currently
  /// loaded [_claims] list (used once claims have finished loading, so the
  /// stat cards reflect live data rather than the stale overview counts).
  _Stats get _activityStats => _Stats(
    total:    _claims.length,
    pending:  _claims.where((c) => c.isPending).length,
    approved: _claims.where((c) => c.isApproved).length,
    rejected: _claims.where((c) => c.isRejected).length,
  );

  // ── Dialog flows ─────────────────────────────────────────────────────────────

  /// Opens [_ClaimDetailDialog] for [claim]. If the user chooses
  /// Approve/Reject from that dialog, opens the corresponding follow-up
  /// confirmation dialog ([_showApproveDialog] / [_showRejectDialog]).
  Future<void> _openClaimDetail(_CreditClaim claim) async {
    final action = await showDialog<_DetailAction>(
      context: context,
      builder: (_) => _ClaimDetailDialog(
        claim:      claim,
        controller: widget.controller,
      ),
    );
    if (!mounted || action == null) return;

    if (action == _DetailAction.approve) {
      await _showApproveDialog(claim);
    } else {
      await _showRejectDialog(claim);
    }
  }

  /// Shows [_ApproveDialog] for [claim]. If the approval API call succeeds
  /// (dialog returns `true`), refreshes the claims table.
  Future<void> _showApproveDialog(_CreditClaim claim) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(claim: claim, controller: widget.controller),
    );
    if (done == true && mounted) _refreshClaims();
  }

  /// Shows [_RejectDialog] for [claim]. If the rejection API call succeeds
  /// (dialog returns `true`), refreshes the claims table.
  Future<void> _showRejectDialog(_CreditClaim claim) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _RejectDialog(claim: claim, controller: widget.controller),
    );
    if (done == true && mounted) _refreshClaims();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Intercept the system back button/gesture: if we're drilled into an
    // activity, treat back as "go to overview" instead of leaving the page.
    return PopScope(
      canPop: _selectedActivity == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: _selectedActivity == null
            ? _buildOverview()
            : _buildActivityView(),
      ),
    );
  }

  // ── Overview screen ──────────────────────────────────────────────────────────

  /// Builds the overview screen: header, global stat cards, search bar,
  /// and the list of activities that have credit claims.
  Widget _buildOverview() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFFFF4D4F))),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadOverview, child: const Text('Retry')),
          ],
        ),
      );
    }
    final stats = _globalStats ?? const _Stats(total: 0, pending: 0, approved: 0, rejected: 0);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadOverview,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── Header card ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x190D1B2A),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Credit Claims',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Review and process student credit claim applications',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5B6B86),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stat cards (vertical, matching dashboard style) ───────────────
            _buildStatCards(stats),
            const SizedBox(height: 18),

            // ── Search bar ────────────────────────────────────────────────────
            _buildSearchBar(),
            const SizedBox(height: 14),

            // ── Activity list ─────────────────────────────────────────────────
            if (_filteredActs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Text(
                    'No activities with claims yet.',
                    style: TextStyle(color: Color(0xFF5B6B86)),
                  ),
                ),
              )
            else
              ..._filteredActs.map(_buildActivityCard),
          ],
        ),
      ),
    );
  }

  /// Search box for filtering activities by name/code on the overview screen.
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search activities by name or code...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3B0), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3B0), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Vertical stack of 4 stat cards — used for both overview and activity view.
  Widget _buildStatCards(_Stats stats) {
    return Column(
      children: [
        _buildStatCard('Total Claims', stats.total,
            Icons.description_outlined, const Color(0xFF2E6BFF), const Color(0xFFE9F1FF)),
        const SizedBox(height: 14),
        _buildStatCard('Pending', stats.pending,
            Icons.access_time_outlined, const Color(0xFFE0A100), const Color(0xFFFFF5D8)),
        const SizedBox(height: 14),
        _buildStatCard('Approved', stats.approved,
            Icons.check_circle_outline, const Color(0xFF0EAF4B), const Color(0xFFE7F9EE)),
        const SizedBox(height: 14),
        _buildStatCard('Rejected', stats.rejected,
            Icons.cancel_outlined, const Color(0xFFFF4D4F), const Color(0xFFFFEDEE)),
      ],
    );
  }

  /// A single stat card (e.g. "Total Claims: 12") with an icon badge.
  Widget _buildStatCard(String label, int value, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 9)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF5B6B86))),
                const SizedBox(height: 6),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor),
          ),
        ],
      ),
    );
  }

  /// Overview-screen card for one activity: name, code, claim count
  /// breakdown, and a "View Claims" button that drills into [_buildActivityView].
  Widget _buildActivityCard(_ClaimActivity a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 9)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity name
          Text(
            a.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 3),
          // Code in blue (matching SRS)
          Text(
            a.code,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2E6BFF)),
          ),
          const SizedBox(height: 14),
          // Count rows
          _countRow('Total Claims', a.total, isTotal: true),
          const SizedBox(height: 10),
          _countRow('Pending',  a.pending,
              badgeColor: const Color(0xFFE0A100), badgeBg: const Color(0xFFFFF5D8)),
          const SizedBox(height: 10),
          _countRow('Approved', a.approved,
              badgeColor: const Color(0xFF0EAF4B), badgeBg: const Color(0xFFE7F9EE)),
          const SizedBox(height: 10),
          _countRow('Rejected', a.rejected,
              badgeColor: const Color(0xFFFF4D4F), badgeBg: const Color(0xFFFFEDEE)),
          const SizedBox(height: 16),
          // View Claims button (full-width blue)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _selectActivity(a),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'View Claims',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A single "label: value" row inside an activity card. The "Total Claims"
  /// row ([isTotal]) is styled as plain blue text, while the status rows
  /// (Pending/Approved/Rejected) render as colored count badges.
  Widget _countRow(String label, int value, {
    bool isTotal = false,
    Color? badgeColor,
    Color? badgeBg,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? const Color(0xFF2E6BFF) : const Color(0xFF5B6B86),
          ),
        ),
        const Spacer(),
        if (isTotal)
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E6BFF),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
      ],
    );
  }

  // ── Activity claims screen ───────────────────────────────────────────────────

  /// Builds the drilled-down activity view: header (with back button),
  /// stat cards for this activity, a student search bar, status filter
  /// tabs, and the table of claims (or loading/error/empty states).
  Widget _buildActivityView() {
    final activity = _selectedActivity!;
    // While claims are still loading, fall back to the counts already known
    // from the overview card so the stat cards don't flash to zero.
    final stats = _claimsLoading && _claims.isEmpty
        ? _Stats(
            total:    activity.total,
            pending:  activity.pending,
            approved: activity.approved,
            rejected: activity.rejected,
          )
        : _activityStats;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshClaims,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── Header card ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x190D1B2A), blurRadius: 22, offset: Offset(0, 10)),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _goBack,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${activity.code}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stat cards ────────────────────────────────────────────────────
            _buildStatCards(stats),
            const SizedBox(height: 18),

            // ── Search bar ────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _studentSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search students...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3B0), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3B0), size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Claims table card ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 9)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Student Credit Claims',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Click on a student to view details and take action',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6B86)),
                  ),
                  const SizedBox(height: 14),

                  // Filter buttons (below the title)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterBtn('All',      0, const Color(0xFF111827)),
                      _filterBtn('Pending',  1, const Color(0xFFE0A100)),
                      _filterBtn('Approved', 2, const Color(0xFF0EAF4B)),
                      _filterBtn('Rejected', 3, const Color(0xFFFF4D4F)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Content
                  if (_claimsLoading && _claims.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_claimsError != null)
                    Center(
                      child: Column(
                        children: [
                          Text(_claimsError!,
                              style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13)),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () => _selectActivity(_selectedActivity!),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (_visibleClaims.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No ${_filterIndex == 0 ? '' : ['', 'pending ', 'approved ', 'rejected '][_filterIndex]}claims found.',
                          style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13),
                        ),
                      ),
                    )
                  else ...[
                    // Table header
                    const Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3B0),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Submitted',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3B0),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Status',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3B0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    // Rows
                    ..._visibleClaims.map(_buildClaimRow),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A single pill-shaped status filter tab (All/Pending/Approved/Rejected).
  /// Tapping it sets [_filterIndex], which [_visibleClaims] uses to filter
  /// the claims table.
  Widget _filterBtn(String label, int index, Color color) {
    final selected = _filterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _filterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  /// A single row in the claims table: student name/ID, submitted date,
  /// and a colored status badge. Tapping the row opens [_openClaimDetail].
  Widget _buildClaimRow(_CreditClaim claim) {
    // Map the raw status string to display label, colors and icon —
    // duplicated (intentionally) in [_ClaimDetailDialog] for the same badge.
    final (statusLabel, statusColor, statusBg, statusIcon) = switch (claim.status) {
      'pending'  => ('Pending',  const Color(0xFFE0A100), const Color(0xFFFFF5D8), Icons.access_time_outlined),
      'claimed'  => ('Approved', const Color(0xFF0EAF4B), const Color(0xFFE7F9EE), Icons.check_circle_outline),
      'rejected' => ('Rejected', const Color(0xFFFF4D4F), const Color(0xFFFFEDEE), Icons.cancel_outlined),
      _          => ('Unknown',  const Color(0xFF9CA3B0), const Color(0xFFF3F4F6), Icons.help_outline),
    };

    return Column(
      children: [
        InkWell(
          onTap: () => _openClaimDetail(claim),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student name + ID
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.student.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (claim.student.studentId != null)
                        Text(
                          claim.student.studentId!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86)),
                        ),
                    ],
                  ),
                ),
                // Submitted date
                Expanded(
                  flex: 7,
                  child: Text(
                    _fmtDate(claim.slot.date),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86)),
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Claim Detail Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Read-only "Claim Details" dialog showing full student/activity/claim
/// info plus the uploaded proof document (if any).
///
/// For pending claims, shows Approve/Reject buttons which close this dialog
/// and return a [_DetailAction] to [_ManageClaimsPageState._openClaimDetail],
/// which then opens the corresponding confirmation dialog. For
/// already-processed claims, only a "Close" button is shown (view-only).
class _ClaimDetailDialog extends StatefulWidget {
  const _ClaimDetailDialog({required this.claim, required this.controller});
  final _CreditClaim claim;
  final AppController controller;

  @override
  State<_ClaimDetailDialog> createState() => _ClaimDetailDialogState();
}

class _ClaimDetailDialogState extends State<_ClaimDetailDialog> {
  /// True while the proof PDF is being downloaded for sharing/saving.
  bool _downloading = false;
  /// True while the proof PDF is being fetched to open in [_PdfViewerPage].
  bool _viewing = false;
  /// Error message (if any) from the last download/view attempt.
  String? _downloadError;

  /// Downloads the proof document bytes and opens the platform share sheet
  /// so the user can save/export the PDF.
  Future<void> _downloadProof() async {
    setState(() { _downloading = true; _downloadError = null; });
    try {
      final bytes = await widget.controller.apiService.downloadProof(
        token:          widget.controller.token!,
        registrationId: widget.claim.id,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'proof_${widget.claim.id}.pdf');
    } catch (e) {
      setState(() => _downloadError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _downloading = false);
    }
  }

  /// Downloads the proof document bytes and pushes [_PdfViewerPage] to
  /// preview it inline (no forced download/share dialog).
  Future<void> _viewProof() async {
    setState(() { _viewing = true; _downloadError = null; });
    try {
      final bytes = await widget.controller.apiService.downloadProof(
        token:          widget.controller.token!,
        registrationId: widget.claim.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PdfViewerPage(
            bytes: bytes,
            title: 'proof_${widget.claim.id}.pdf',
          ),
        ),
      );
    } catch (e) {
      setState(() => _downloadError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;

    final (statusLabel, statusColor, statusBg, statusIcon) = switch (claim.status) {
      'pending'  => ('Pending',  const Color(0xFFE0A100), const Color(0xFFFFF5D8), Icons.access_time_outlined),
      'claimed'  => ('Approved', const Color(0xFF0EAF4B), const Color(0xFFE7F9EE), Icons.check_circle_outline),
      'rejected' => ('Rejected', const Color(0xFFFF4D4F), const Color(0xFFFFEDEE), Icons.cancel_outlined),
      _          => ('Unknown',  const Color(0xFF9CA3B0), const Color(0xFFF3F4F6), Icons.help_outline),
    };

    // Strip the directory portion of the stored proof path so only the
    // filename is shown to the user (handles both '/' and '\' separators).
    final proofName = claim.proofPath?.split('/').last.split('\\').last;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Centered header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Claim Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'View complete information about this credit claim',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF5B6B86), height: 1.35),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22, color: Color(0xFF5B6B86)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 16),

            // ── Claim Information + status badge ─────────────────────────────
            Row(
              children: [
                const Text(
                  'Claim Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Student Information card ──────────────────────────────────────
            _sectionLabel('Student Information'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _infoCell('Name', claim.student.name),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _infoCell(
                      'Student ID',
                      claim.student.studentId ?? '—',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Activity Information card ─────────────────────────────────────
            _sectionLabel('Activity Information'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _infoCell('Activity Name', claim.activity.name)),
                      const SizedBox(width: 12),
                      Expanded(child: _infoCell('Activity Code', claim.activity.code)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _infoCell('CATs Claimed', '${claim.activity.cats}')),
                      const SizedBox(width: 12),
                      Expanded(child: _infoCell('Submitted Date', _fmtDate(claim.slot.date))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Description (slot time / location) ───────────────────────────
            _sectionLabel('Description'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                [
                  'Time: ${claim.slot.time}',
                  if (claim.activity.location != null) 'Location: ${claim.activity.location}',
                  if (claim.remarks != null && claim.remarks!.isNotEmpty) 'Remarks: ${claim.remarks}',
                  if (claim.rejectionReason != null && claim.rejectionReason!.isNotEmpty)
                    'Rejection reason: ${claim.rejectionReason}',
                ].join('\n'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5),
              ),
            ),
            const SizedBox(height: 14),

            // ── Supporting Documents ──────────────────────────────────────────
            _sectionLabel('Supporting Documents'),
            const SizedBox(height: 8),
            if (_downloadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _downloadError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF4D4F)),
                ),
              ),
            if (proofName != null)
              _proofFileItem(proofName)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No supporting document uploaded.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3B0)),
                ),
              ),
            const SizedBox(height: 22),

            // ── Action buttons (vertical stack per SRS) ────────────────────────
            // Only pending claims can still be approved/rejected — for claims
            // already processed, this dialog is view-only (Close button only).
            if (claim.isPending) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _DetailAction.approve),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0EAF4B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _DetailAction.reject),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4D4F),
                    side: const BorderSide(color: Color(0xFFFF4D4F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B6B86),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small uppercase-style heading used above each info card section
  /// (e.g. "Student Information", "Activity Information").
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5B6B86)),
    );
  }

  /// A "label" + "value" pair displayed stacked vertically, used inside
  /// the info cards (e.g. Name / Student ID, Activity Name / Code).
  Widget _infoCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3B0), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
        ),
      ],
    );
  }

  /// The uploaded proof document row: tapping the filename/icon area opens
  /// [_viewProof] (inline PDF preview), while the trailing download icon
  /// triggers [_downloadProof] (share/save). Each action shows its own
  /// small loading spinner while in progress.
  Widget _proofFileItem(String filename) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _viewing ? null : _viewProof,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFF4D4F), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      filename,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_viewing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E6BFF)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _downloading ? null : _downloadProof,
            child: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E6BFF)),
                  )
                : const Icon(Icons.download_outlined, size: 22, color: Color(0xFF2E6BFF)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PDF Viewer Page (inline preview, no forced download)
// ═══════════════════════════════════════════════════════════════════════════════

/// Full-screen PDF preview page used by [_ClaimDetailDialogState._viewProof]
/// to display a proof document inline, without forcing a download/share
/// dialog like [_ClaimDetailDialogState._downloadProof] does.
class _PdfViewerPage extends StatelessWidget {
  const _PdfViewerPage({required this.bytes, required this.title});

  /// Raw PDF bytes already downloaded via [ApiService.downloadProof].
  final Uint8List bytes;
  /// Title shown in the app bar (the proof filename).
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Approve Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Confirmation dialog for approving a pending credit claim.
///
/// Lets Pusat Adab optionally add remarks before approving. On success,
/// pops with `true` so [_ManageClaimsPageState._showApproveDialog] knows to
/// refresh the claims table; the student is notified by the backend.
class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.claim, required this.controller});
  final _CreditClaim claim;
  final AppController controller;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  /// Optional remarks to attach to the approval.
  final _remarksCtrl = TextEditingController();
  /// True while [_approve] is in flight — disables inputs/buttons.
  bool    _loading = false;
  /// Error message (if any) from the last approve attempt.
  String? _error;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  /// Calls the approve-claim API for [widget.claim], sending trimmed remarks
  /// (or null if empty). On success, closes the dialog returning `true`.
  Future<void> _approve() async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.controller.apiService.approveClaim(
        token:          widget.controller.token!,
        registrationId: widget.claim.id,
        // Send null instead of an empty string so the backend doesn't store
        // a blank remarks value.
        remarks:        _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Centered header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Approve Credit Claim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirm approval of this credit claim. The student will be notified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF5B6B86), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loading ? null : () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: Color(0xFF5B6B86)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Info box (green) ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F9EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoLine('Student', claim.student.name),
                  const SizedBox(height: 4),
                  _infoLine('Activity', claim.activity.name),
                  const SizedBox(height: 4),
                  _infoLine('Cats', '${claim.activity.cats}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Remarks field ────────────────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Remarks (Optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remarksCtrl,
              maxLines: 3,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: 'Add any remarks or comments...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3B0)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0EAF4B), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF4D4F))),
              ),
            ],
            const SizedBox(height: 20),

            // ── Approve button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _approve,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAF4B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Approve Claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),

            // ── Cancel button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B6B86),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Label: value" line with the label rendered bold (used in the
  /// summary info box shown above the remarks/reason field).
  Widget _infoLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reject Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Confirmation dialog for rejecting a pending credit claim.
///
/// Requires a non-empty rejection reason (validated in [_reject]). On
/// success, pops with `true` so [_ManageClaimsPageState._showRejectDialog]
/// knows to refresh the claims table; the student is notified with the
/// reason by the backend.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.claim, required this.controller});
  final _CreditClaim claim;
  final AppController controller;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  /// Required reason text explaining why the claim is rejected.
  final _reasonCtrl = TextEditingController();
  /// True while [_reject] is in flight — disables inputs/buttons.
  bool    _loading = false;
  /// Error message (if any) — either client-side validation or API error.
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  /// Validates that a rejection reason was entered, then calls the
  /// reject-claim API for [widget.claim]. On success, closes the dialog
  /// returning `true`.
  Future<void> _reject() async {
    final reason = _reasonCtrl.text.trim();
    // Client-side validation — backend also requires a reason, but failing
    // fast here avoids an unnecessary network round trip.
    if (reason.isEmpty) {
      setState(() => _error = 'Reason for rejection is required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.controller.apiService.rejectClaim(
        token:          widget.controller.token!,
        registrationId: widget.claim.id,
        reason:         reason,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Centered header ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Reject Credit Claim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please provide a reason for rejecting this claim. The student will be notified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF5B6B86), height: 1.4),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _loading ? null : () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: Color(0xFF5B6B86)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Info box (red) ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoLine('Student', claim.student.name),
                  const SizedBox(height: 4),
                  _infoLine('Activity', claim.activity.name),
                  const SizedBox(height: 4),
                  _infoLine('Cats', '${claim.activity.cats}'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Reason field ─────────────────────────────────────────────────
            Row(
              children: [
                const Text(
                  'Reason for Rejection',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
                const SizedBox(width: 4),
                const Text(' *', style: TextStyle(fontSize: 13, color: Color(0xFFFF4D4F), fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: 'Please explain why this claim is being rejected...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3B0)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFF4D4F), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF4D4F))),
              ),
            ],
            const SizedBox(height: 20),

            // ── Reject button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _reject,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D4F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Reject Claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),

            // ── Cancel button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B6B86),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Label: value" line with the label rendered bold (used in the
  /// summary info box shown above the rejection reason field).
  Widget _infoLine(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
