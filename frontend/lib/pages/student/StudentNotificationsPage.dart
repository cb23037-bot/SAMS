import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';

/// Embedded widget — no Scaffold. Used inside [StudentHomePage] for the
/// "Notification" tab.
///
/// Shows the student's activity registrations that have a status update
/// (claimed/pending/rejected); fresh "not_claimed" registrations are
/// excluded since there's nothing to notify about yet. Tapping a card
/// navigates back to the Curriculum Activity page via [onOpenActivity].
class StudentNotificationsContent extends StatefulWidget {
  const StudentNotificationsContent({
    super.key,
    required this.controller,
    required this.lastViewed,
    required this.onOpenActivity,
  });

  final AppController controller;

  /// Timestamp of when the student last opened this tab. Registrations
  /// updated after this time are considered "new" (see [_isNew]).
  /// Null means the tab has never been viewed, so everything is "new".
  final DateTime? lastViewed;

  /// Called when the student taps a notification card — navigates to the
  /// related activity registration on the Curriculum Activity page.
  final void Function(ActivityRegistration reg) onOpenActivity;

  @override
  State<StudentNotificationsContent> createState() => _StudentNotificationsContentState();
}

class _StudentNotificationsContentState extends State<StudentNotificationsContent> {
  /// The student's registrations with a status update, sorted newest-first.
  /// Null while [_load] hasn't completed yet (shows a loading spinner).
  List<ActivityRegistration>? _registrations;

  /// Error message from the last failed [_load] call, or null if no error.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches the student's registrations, keeps only those with a status
  /// update (excludes 'not_claimed'), and sorts them newest-first by
  /// [ActivityRegistration.updatedAt].
  Future<void> _load() async {
    setState(() { _error = null; });
    try {
      final regs = await widget.controller.apiService.getStudentRegistrations(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      setState(() {
        _registrations = regs
            .where((r) => r.claimStatus != 'not_claimed')
            .toList()
          ..sort((a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// True if [reg] was updated after [widget.lastViewed] (or if the tab has
  /// never been viewed). Drives the "new" badge/dot shown on each card.
  bool _isNew(ActivityRegistration reg) {
    final lastViewed = widget.lastViewed;
    if (lastViewed == null) return true;
    final updatedAt = reg.updatedAt;
    if (updatedAt == null) return false;
    return DateTime.tryParse(updatedAt)?.isAfter(lastViewed) ?? false;
  }

  /// Builds the title row (with a "X new" badge if applicable) and the
  /// body, which switches between a loading spinner, error view, empty
  /// state, or the list of notification cards.
  @override
  Widget build(BuildContext context) {
    final regs = _registrations;
    // Count how many of the loaded registrations are unseen, for the badge.
    final newCount = regs?.where(_isNew).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              if (newCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5BFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$newCount new',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: regs == null && _error == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A96A8))),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : regs!.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none_outlined, size: 60, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(color: Color(0xFF8A96A8), fontSize: 15),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Claim activity credits to see updates here.',
                                style: TextStyle(color: Color(0xFFAFBACC), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: regs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _NotifCard(
                              reg: regs[i],
                              isNew: _isNew(regs[i]),
                              onTap: () => widget.onOpenActivity(regs[i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────────

/// Single notification card showing the activity name/code, a status icon
/// and badge (resolved via [_resolveStyle]), a status message, the
/// rejection reason if applicable, and a relative timestamp.
///
/// Shows an unread dot when [isNew] is true. Tapping the card calls [onTap]
/// to navigate to the related registration on the Curriculum Activity page.
class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.reg, required this.isNew, required this.onTap});

  final ActivityRegistration reg;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();
    final updatedAt = reg.updatedAt != null ? DateTime.tryParse(reg.updatedAt!) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew ? const Color(0xFFBFD4FF) : const Color(0xFFE8EDF6),
          width: isNew ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0D1B2A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            SizedBox(
              width: 14,
              child: isNew
                  ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E5BFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),

            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: style.iconBg, shape: BoxShape.circle),
              child: Icon(style.icon, color: style.iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reg.activity.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(label: style.badgeLabel, bg: style.badgeBg, fg: style.badgeFg),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reg.activity.code,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    style.message,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                  ),
                  if (reg.isRejected &&
                      reg.rejectionReason != null &&
                      reg.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD9DB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reason for rejection',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF3B30),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reg.rejectionReason!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (updatedAt != null)
                    Text(
                      _formatRelative(updatedAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAFBACC)),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Maps [reg.claimStatus] ('claimed' | 'pending' | 'rejected' | other) to
  /// the icon, colors, badge label, and message text shown on the card.
  _NotifStyle _resolveStyle() {
    switch (reg.claimStatus) {
      case 'claimed':
        return _NotifStyle(
          icon: Icons.check_circle_outline,
          iconBg: const Color(0xFFE7F9EE),
          iconColor: const Color(0xFF0EAF4B),
          badgeLabel: 'Approved',
          badgeBg: const Color(0xFFE7F9EE),
          badgeFg: const Color(0xFF0EAF4B),
          message:
              'Your credit claim has been approved. '
              '${reg.activity.cats} CAT${reg.activity.cats == 1 ? '' : 's'} '
              'have been added to your academic record.',
        );
      case 'pending':
        return _NotifStyle(
          icon: Icons.access_time_outlined,
          iconBg: const Color(0xFFFFF5D8),
          iconColor: const Color(0xFFD4960A),
          badgeLabel: 'Pending',
          badgeBg: const Color(0xFFFFF5D8),
          badgeFg: const Color(0xFFD4960A),
          message:
              'Your credit claim is under review. '
              'Please wait for the approval from Pusat Adab.',
        );
      case 'rejected':
        return _NotifStyle(
          icon: Icons.cancel_outlined,
          iconBg: const Color(0xFFFFEDEE),
          iconColor: const Color(0xFFFF4D4F),
          badgeLabel: 'Rejected',
          badgeBg: const Color(0xFFFFEDEE),
          badgeFg: const Color(0xFFFF4D4F),
          message:
              'Your credit claim has been rejected. '
              'Please contact Pusat Adab for more information.',
        );
      default:
        return _NotifStyle(
          icon: Icons.info_outline,
          iconBg: const Color(0xFFF3F4F6),
          iconColor: const Color(0xFF6B7280),
          badgeLabel: 'Unknown',
          badgeBg: const Color(0xFFF3F4F6),
          badgeFg: const Color(0xFF6B7280),
          message: '',
        );
    }
  }

  /// Formats [dt] as a relative time ("Just now", "5 min ago", "2 days ago")
  /// followed by an absolute date/time, e.g. "2 days ago  •  Jun 12, 2026  •  3:45 PM".
  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final String relative;
    if (diff.inDays >= 1) {
      final d = diff.inDays;
      relative = '$d day${d == 1 ? '' : 's'} ago';
    } else if (diff.inHours >= 1) {
      final h = diff.inHours;
      relative = '$h hour${h == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes >= 1) {
      relative = '${diff.inMinutes} min ago';
    } else {
      relative = 'Just now';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[dt.month - 1];
    final rawHour = dt.hour;
    final hour = rawHour == 0 ? 12 : (rawHour > 12 ? rawHour - 12 : rawHour);
    final ampm = rawHour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$relative  •  $month ${dt.day}, ${dt.year}  •  $hour:$minute $ampm';
  }
}

/// Visual styling for a [_NotifCard], resolved by [_NotifCard._resolveStyle]
/// based on the registration's claim status.
class _NotifStyle {
  const _NotifStyle({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeFg,
    required this.message,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeFg;
  final String message;
}

/// Small rounded "pill" label (e.g. "Approved", "Pending", "Rejected")
/// shown in the top-right corner of a [_NotifCard].
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
