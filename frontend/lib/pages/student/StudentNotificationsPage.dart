import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';

class StudentNotificationsContent extends StatefulWidget {
  const StudentNotificationsContent({
    super.key,
    required this.controller,
    required this.lastViewed,
  });

  final AppController controller;
  final DateTime? lastViewed;

  @override
  State<StudentNotificationsContent> createState() => _StudentNotificationsContentState();
}

class _StudentNotificationsContentState extends State<StudentNotificationsContent> {
  List<ActivityRegistration>? _registrations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  bool _isNew(ActivityRegistration reg) {
    final lastViewed = widget.lastViewed;
    if (lastViewed == null) return true;
    final updatedAt = reg.updatedAt;
    if (updatedAt == null) return false;
    return DateTime.tryParse(updatedAt)?.isAfter(lastViewed) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final regs = _registrations;
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
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

// ── Notification card ──────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.reg, required this.isNew});

  final ActivityRegistration reg;
  final bool isNew;

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
    );
  }

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
