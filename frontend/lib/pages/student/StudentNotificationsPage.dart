import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/unified_notification.dart';
import 'fees/manage_fees_dashboard_page.dart';

/// Embedded widget — no Scaffold. Used inside [StudentHomePage] for the
/// "Notification" tab.
///
/// Shows a unified list of all student notifications: Module 2 activity
/// credit claim updates and Module 3 fee/restriction/payment notifications,
/// sorted newest-first. Fee notification taps navigate to [ManageFeesDashboardPage];
/// activity notification taps invoke [onOpenCurriculum].
class StudentNotificationsContent extends StatefulWidget {
  const StudentNotificationsContent({
    super.key,
    required this.controller,
    this.onOpenCurriculum,
  });

  final AppController controller;

  /// Called when the student taps an activity credit-claim notification.
  /// Should navigate to the Curriculum Activity page.
  final VoidCallback? onOpenCurriculum;

  @override
  State<StudentNotificationsContent> createState() => _StudentNotificationsContentState();
}

class _StudentNotificationsContentState extends State<StudentNotificationsContent> {
  List<UnifiedNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final notifs = await widget.controller.apiService.getAllNotifications(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      setState(() => _notifications = notifs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifs = _notifications;
    final unreadCount = notifs?.where((n) => !n.isRead).length ?? 0;

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
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5BFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unreadCount new',
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
          child: notifs == null && _error == null
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
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF8A96A8)),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : notifs!.isEmpty
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
                                "You'll see updates about your fees and credit claims here.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFFAFBACC), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: notifs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _UnifiedNotifCard(
                              notification: notifs[i],
                              onTap: () => _handleTap(notifs[i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  Future<void> _handleTap(UnifiedNotification notif) async {
    if (notif.type == 'fees') {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManageFeesDashboardPage(controller: widget.controller),
      ));
      // Mark the notification as read on the backend after returning
      if (!notif.isRead) {
        try {
          final id = int.tryParse(notif.id.replaceFirst('fee_', ''));
          if (id != null) {
            await widget.controller.apiService.markNotificationRead(
              token: widget.controller.token!,
              id: id,
            );
          }
        } catch (_) {}
        if (mounted) _load();
      }
    } else {
      // Activity credit-claim notification — open Curriculum Activity page
      widget.onOpenCurriculum?.call();
    }
  }
}

// ── Unified notification card ──────────────────────────────────────────────────

class _UnifiedNotifCard extends StatelessWidget {
  const _UnifiedNotifCard({required this.notification, required this.onTap});

  final UnifiedNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle();
    final bool isNew = !notification.isRead;

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
                            notification.title,
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
                        _StatusBadge(
                          label: style.badgeLabel,
                          bg: style.badgeBg,
                          fg: style.badgeFg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatRelative(notification.createdAt),
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

  _NotifStyle _resolveStyle() {
    if (notification.type == 'activity') {
      switch (notification.status) {
        case 'claimed':
          return const _NotifStyle(
            icon: Icons.check_circle_outline,
            iconBg: Color(0xFFE7F9EE),
            iconColor: Color(0xFF0EAF4B),
            badgeLabel: 'Approved',
            badgeBg: Color(0xFFE7F9EE),
            badgeFg: Color(0xFF0EAF4B),
          );
        case 'rejected':
          return const _NotifStyle(
            icon: Icons.cancel_outlined,
            iconBg: Color(0xFFFFEDEE),
            iconColor: Color(0xFFFF4D4F),
            badgeLabel: 'Rejected',
            badgeBg: Color(0xFFFFEDEE),
            badgeFg: Color(0xFFFF4D4F),
          );
        default: // pending
          return const _NotifStyle(
            icon: Icons.access_time_outlined,
            iconBg: Color(0xFFFFF5D8),
            iconColor: Color(0xFFD4960A),
            badgeLabel: 'Pending',
            badgeBg: Color(0xFFFFF5D8),
            badgeFg: Color(0xFFD4960A),
          );
      }
    }

    // type == 'fees'
    switch (notification.status) {
      case 'restriction':
        return const _NotifStyle(
          icon: Icons.block_outlined,
          iconBg: Color(0xFFFFEDEE),
          iconColor: Color(0xFFFF4D4F),
          badgeLabel: 'Restricted',
          badgeBg: Color(0xFFFFEDEE),
          badgeFg: Color(0xFFFF4D4F),
        );
      case 'access_restored':
        return const _NotifStyle(
          icon: Icons.lock_open_outlined,
          iconBg: Color(0xFFE7F9EE),
          iconColor: Color(0xFF0EAF4B),
          badgeLabel: 'Restored',
          badgeBg: Color(0xFFE7F9EE),
          badgeFg: Color(0xFF0EAF4B),
        );
      case 'payment_success':
        return const _NotifStyle(
          icon: Icons.receipt_long_outlined,
          iconBg: Color(0xFFE7F9EE),
          iconColor: Color(0xFF0EAF4B),
          badgeLabel: 'Paid',
          badgeBg: Color(0xFFE7F9EE),
          badgeFg: Color(0xFF0EAF4B),
        );
      default:
        return const _NotifStyle(
          icon: Icons.account_balance_wallet_outlined,
          iconBg: Color(0xFFEEF2FF),
          iconColor: Color(0xFF4F5CF4),
          badgeLabel: 'Fee',
          badgeBg: Color(0xFFEEF2FF),
          badgeFg: Color(0xFF4F5CF4),
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

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeFg;
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
