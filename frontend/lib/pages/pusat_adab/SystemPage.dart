import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import 'AdabNotificationsPage.dart';
import 'ActivityFormPage.dart';
import 'CreditClaimPage.dart';

class PusatAdabDashboardPage extends StatefulWidget {
  const PusatAdabDashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<PusatAdabDashboardPage> createState() => _PusatAdabDashboardPageState();
}

class _PusatAdabDashboardPageState extends State<PusatAdabDashboardPage> {
  int  _totalActivities = 0;
  int  _pending         = 0;
  int  _approved        = 0;
  int  _rejected        = 0;
  bool _loading         = true;
  bool _accessOpen      = true;
  bool _accessToggling  = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.controller.apiService.getClaimsOverview(token: widget.controller.token!),
        widget.controller.apiService.getAdabAccess(token: widget.controller.token!),
      ]);
      final s = (results[0] as Map<String, dynamic>)['stats'] as Map<String, dynamic>;
      setState(() {
        _totalActivities = (s['activitiesTotal'] as num).toInt();
        _pending         = (s['pending']         as num).toInt();
        _approved        = (s['approved']         as num).toInt();
        _rejected        = (s['rejected']         as num).toInt();
        _accessOpen      = results[1] as bool;
      });
    } catch (_) {
      // silently keep previous values on error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdabNotificationsPage(controller: widget.controller),
      ),
    );
    _loadStats(); // refresh pending count badge when returning
  }

  Future<void> _toggleAccess(bool open) async {
    setState(() => _accessToggling = true);
    try {
      final result = await widget.controller.apiService.setAdabAccess(
        token: widget.controller.token!,
        open:  open,
      );
      setState(() => _accessOpen = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _accessToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            child: Column(
              children: [
                _HeaderCard(
                  controller:   widget.controller,
                  pendingCount: _loading ? 0 : _pending,
                  onNotifTap:   _openNotifications,
                ),
                const SizedBox(height: 22),
                _StatCard(
                  title: 'Total Activities',
                  value: _loading ? '—' : '$_totalActivities',
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF2E6BFF),
                  iconBackground: const Color(0xFFE9F1FF),
                ),
                const SizedBox(height: 18),
                _StatCard(
                  title: 'Pending Claims',
                  value: _loading ? '—' : '$_pending',
                  icon: Icons.access_time_outlined,
                  iconColor: const Color(0xFFE0A100),
                  iconBackground: const Color(0xFFFFF5D8),
                ),
                const SizedBox(height: 18),
                _StatCard(
                  title: 'Approved Claims',
                  value: _loading ? '—' : '$_approved',
                  icon: Icons.check_circle_outline,
                  iconColor: const Color(0xFF0EAF4B),
                  iconBackground: const Color(0xFFE7F9EE),
                ),
                const SizedBox(height: 18),
                _StatCard(
                  title: 'Rejected Claims',
                  value: _loading ? '—' : '$_rejected',
                  icon: Icons.cancel_outlined,
                  iconColor: const Color(0xFFFF4D4F),
                  iconBackground: const Color(0xFFFFEDEE),
                ),
              const SizedBox(height: 18),
              _AccessControlCard(
                accessOpen: _accessOpen,
                toggling:   _accessToggling,
                onOpen:     () => _toggleAccess(true),
                onClose:    () => _toggleAccess(false),
              ),
              const SizedBox(height: 18),
              _ManagementCard(
                title: 'Manage Curriculum Activities',
                description:
                    'Add, edit, delete, and manage curriculum activities in the system',
                icon: Icons.calendar_today_outlined,
                accentColor: const Color(0xFF2E6BFF),
                buttonLabel: 'Go to Activities Management',
                buttonColor: const Color(0xFF2E6BFF),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CurriculumActivitiesPage(controller: widget.controller),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ManagementCard(
                title: 'Manage Credit Claims',
                description:
                    'Review, approve, or reject student credit claim applications',
                icon: Icons.assignment_outlined,
                accentColor: const Color(0xFF0EAF4B),
                buttonLabel: 'Go to Claims Management',
                buttonColor: const Color(0xFF08A53F),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManageClaimsPage(controller: widget.controller),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.controller,
    required this.pendingCount,
    required this.onNotifTap,
  });

  final AppController controller;
  final int pendingCount;
  final VoidCallback onNotifTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardBrandMark(),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pusat Adab Dashboard',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage curriculum activities and credit claims',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6B86),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onNotifTap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5F9DFF)),
                    foregroundColor: const Color(0xFF2E6BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_none_outlined),
                      if (pendingCount > 0)
                        Positioned(
                          top: -8,
                          right: -11,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4747),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.isLoading
                      ? null
                      : () => controller.signOut(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF9E9E)),
                    foregroundColor: const Color(0xFFFF3B30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: controller.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardBrandMark extends StatelessWidget {
  const _DashboardBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF5B6B86),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
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
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _AccessControlCard extends StatelessWidget {
  const _AccessControlCard({
    required this.accessOpen,
    required this.toggling,
    required this.onOpen,
    required this.onClose,
  });

  final bool accessOpen;
  final bool toggling;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cardBg     = accessOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F1);
    final cardBorder = accessOpen ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final iconColor  = accessOpen ? const Color(0xFF08A53F) : const Color(0xFFDC2626);
    final iconData   = accessOpen ? Icons.lock_open_outlined : Icons.lock_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row with status badge ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Access Control',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Control student access to module registration and credit claims',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6B86),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge (not a button — shows current state)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accessOpen ? const Color(0xFF08A53F) : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  accessOpen ? 'OPEN' : 'CLOSED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Status detail + action button ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessOpen
                      ? 'Current Status: Students can register modules and claim credits'
                      : 'Current Status: Access is closed. Students cannot register or claim credits',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: toggling
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : accessOpen
                          ? FilledButton.icon(
                              onPressed: onClose,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.lock_outline, size: 16),
                              label: const Text(
                                'Close Access',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: onOpen,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF08A53F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.lock_open_outlined, size: 16),
                              label: const Text(
                                'Open Access',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B6B86),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
