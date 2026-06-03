import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class AdabNotificationsPage extends StatefulWidget {
  const AdabNotificationsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdabNotificationsPage> createState() => _AdabNotificationsPageState();
}

class _AdabNotificationsPageState extends State<AdabNotificationsPage> {
  // Persists across rebuilds so "new" status is accurate after returning.
  static DateTime? _sLastViewed;

  List<_ClaimNotif>? _claims;
  int _pendingCount = 0;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Record when the user last viewed this page so future visits can mark
    // only newly submitted claims as "new".
    _sLastViewed = DateTime.now();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final json = await widget.controller.apiService.getAdabNotifications(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      setState(() {
        _pendingCount = (json['pending_count'] as num).toInt();
        _claims = (json['claims'] as List<dynamic>)
            .map((c) => _ClaimNotif.fromJson(c as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isNew(_ClaimNotif notif) {
    final lastViewed = _sLastViewed;
    if (lastViewed == null) return true;
    final ts = notif.submittedAt;
    if (ts == null) return false;
    return DateTime.tryParse(ts)?.isAfter(lastViewed) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final claims = _claims ?? [];
    final newCount = claims.where(_isNew).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Custom header ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (newCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E5BFF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$newCount new',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'Stay updated with credit claim submissions',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 52, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A96A8))),
                                const SizedBox(height: 16),
                                OutlinedButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : claims.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_outlined, size: 60, color: Color(0xFFCBD5E1)),
                                  SizedBox(height: 12),
                                  Text(
                                    'No pending claims',
                                    style: TextStyle(color: Color(0xFF8A96A8), fontSize: 15),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'New credit claims will appear here.',
                                    style: TextStyle(color: Color(0xFFAFBACC), fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                // +1 for the "Pending Claims Reminder" card at the end
                                itemCount: claims.length + 1,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  if (i == claims.length) {
                                    return _PendingReminderCard(count: _pendingCount);
                                  }
                                  return _NewClaimCard(
                                    notif: claims[i],
                                    isNew: _isNew(claims[i]),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ClaimNotif {
  const _ClaimNotif({
    required this.claimId,
    required this.studentName,
    required this.studentIdStr,
    required this.activityName,
    required this.activityCode,
    this.submittedAt,
  });

  final int claimId;
  final String studentName;
  final String studentIdStr;
  final String activityName;
  final String activityCode;
  final String? submittedAt;

  factory _ClaimNotif.fromJson(Map<String, dynamic> json) {
    final student  = json['student']  as Map<String, dynamic>;
    final activity = json['activity'] as Map<String, dynamic>;
    return _ClaimNotif(
      claimId:      (json['id'] as num).toInt(),
      studentName:  student['name'] as String,
      studentIdStr: student['student_id'] as String? ?? '',
      activityName: activity['name'] as String,
      activityCode: activity['code'] as String,
      submittedAt:  json['submitted_at'] as String?,
    );
  }
}

// ── New Claim card ────────────────────────────────────────────────────────────

class _NewClaimCard extends StatelessWidget {
  const _NewClaimCard({required this.notif, required this.isNew});

  final _ClaimNotif notif;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final submittedAt = notif.submittedAt != null ? DateTime.tryParse(notif.submittedAt!) : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew ? const Color(0xFFBFD4FF) : const Color(0xFFE8EDF6),
          width: isNew ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
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

            // Document icon
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFF2E6BFF), size: 22),
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
                          notif.activityName,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'New Claim',
                          style: TextStyle(
                            color: Color(0xFF2E6BFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
                      children: [
                        TextSpan(
                          text: notif.studentName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: '  •  ${notif.studentIdStr}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Code: ${notif.activityCode}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
                  ),
                  const SizedBox(height: 7),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                      children: [
                        const TextSpan(text: 'New credit claim submitted for '),
                        TextSpan(
                          text: notif.activityName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: '. Please review and process the claim.'),
                      ],
                    ),
                  ),
                  if (submittedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatRelative(submittedAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAFBACC)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final String relative;
    if (diff.inDays == 0) {
      if (diff.inHours >= 1) {
        final h = diff.inHours;
        relative = '$h hour${h == 1 ? '' : 's'} ago';
      } else if (diff.inMinutes >= 1) {
        relative = '${diff.inMinutes} min ago';
      } else {
        relative = 'Just now';
      }
    } else if (diff.inDays == 1) {
      relative = '1 day ago';
    } else {
      relative = '${diff.inDays} days ago';
    }

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final month  = months[dt.month - 1];
    final rawH   = dt.hour;
    final hour   = rawH == 0 ? 12 : (rawH > 12 ? rawH - 12 : rawH);
    final ampm   = rawH >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$relative  •  $month ${dt.day}, ${dt.year}  •  $hour:$minute $ampm';
  }
}

// ── Pending Claims Reminder card ──────────────────────────────────────────────

class _PendingReminderCard extends StatelessWidget {
  const _PendingReminderCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [
          BoxShadow(color: Color(0x0D0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 14), // align with claim cards

            // Clock icon
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF5D8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_outlined, color: Color(0xFFD4960A), size: 22),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Pending Claims',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5D8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Reminder',
                          style: TextStyle(
                            color: Color(0xFFD4960A),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'You have $count pending credit claim${count == 1 ? '' : 's'} waiting for review. '
                    'Please process them promptly.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
