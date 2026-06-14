// lecturer_dashboard.dart — Boundary Screen
// Requirement ID : SAMS-PACK-406
// Responsibility : Displays the lecturer dashboard with today's class schedules and
//                  quick access to attendance management and reports.
//
// Attributes:
//   lecturerData    User
//   todaySchedule   ClassSchedule
//   navigation      Navigation
//
// Methods:
//   render()               — Renders lecturer dashboard interface.
//   loadTodaySchedule()    — Retrieves lecturer's schedule for the current date.
//   navigateToClassList()  — Navigates to lecturer class list screen.

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/animations.dart';
import '../login_screen.dart';
import 'lecturer_class_list.dart';
import 'lecturer_active_session.dart';
import 'lecturer_attendance_report.dart';

class LecturerDashboard extends StatefulWidget {
  final UserModel user;
  const LecturerDashboard({super.key, required this.user});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  List<ClassScheduleModel> _todaySchedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // loadTodaySchedule() — SAMS-PACK-406
    _loadTodaySchedule();
  }

  // loadTodaySchedule() — List<ClassSchedule>
  // SAMS-PACK-406
  // GET lecturer_id from session → CALL ClassSchedule.getTodaySchedule(lecturer_id)
  Future<void> _loadTodaySchedule() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getTodaySchedules();
      if (res['status'] == 200) {
        setState(() {
          _todaySchedules = (res['schedules'] as List)
              .map((j) => ClassScheduleModel.fromJson(j))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  // logout() — void
  // Terminates the current user session and navigates back to login screen.
  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatDate(DateTime d) {
    const days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // navigateToClassList() — void
  // SAMS-PACK-406
  // Navigates to any lecturer screen using a slide-up transition.
  void _navigate(Widget page) {
    Navigator.push(context, SlideUpRoute(page: page));
  }

  // render() — void
  // SAMS-PACK-406
  // Displays lecturer name, today's session cards, and quick action buttons.
  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: RefreshIndicator(
        onRefresh: _loadTodaySchedule,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF1A3A6B),
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_outlined, size: 20),
                  onPressed: _logout,
                  tooltip: 'Sign out',
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F2449), Color(0xFF1A3A6B)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.school, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text('SAMS',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 16),
                          Text('${_greeting()}, $firstName',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(_formatDate(DateTime.now()),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                  ? _LecturerSkeleton()
                  : _LecturerBody(
                      schedules: _todaySchedules,
                      user: widget.user,
                      onNavigate: _navigate,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────
class _LecturerSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ShimmerBox(width: 110, height: 16, borderRadius: 6),
      SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 120, borderRadius: 14),
      SizedBox(height: 10),
      ShimmerBox(width: double.infinity, height: 120, borderRadius: 14),
      SizedBox(height: 24),
      ShimmerBox(width: 110, height: 16, borderRadius: 6),
      SizedBox(height: 12),
      Row(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: 96, borderRadius: 14)),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(width: double.infinity, height: 96, borderRadius: 14)),
      ]),
    ]);
  }
}

// ─── Loaded body ──────────────────────────────────────────────────────────────
// render() — void  (SAMS-PACK-406)
// Displays today's schedule cards and quick action tiles.
class _LecturerBody extends StatelessWidget {
  final List<ClassScheduleModel> schedules;
  final UserModel user;
  final void Function(Widget) onNavigate;

  const _LecturerBody({
    required this.schedules,
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return StaggerList(
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Today's Classes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),
            Pressable(
              onTap: () => onNavigate(LecturerClassList(user: user)),
              scale: 0.95,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('View all',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A3A6B))),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Schedule cards or empty state
        if (schedules.isEmpty)
          const _EmptyCard(
            icon: Icons.calendar_today_outlined,
            title: 'No classes today',
            subtitle: 'Your schedule is clear for today.',
          )
        else
          // navigateToClassList() / onViewSession() — SAMS-PACK-406
          // "Manage Attendance" navigates to class list.
          // "View Code" navigates directly to the active session when one exists.
          ...schedules.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScheduleCard(
              schedule: s,
              onManage: () => onNavigate(LecturerClassList(user: user)),
              onViewSession: s.activeSession != null
                ? () => onNavigate(LecturerActiveSession(schedule: s, session: s.activeSession!))
                : null,
            ),
          )),

        const SizedBox(height: 24),

        const Text('Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),

        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _ActionTile(
            icon: Icons.fact_check_outlined,
            label: 'Manage\nAttendance',
            color: const Color(0xFF1A3A6B),
            onTap: () => onNavigate(LecturerClassList(user: user)),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionTile(
            icon: Icons.bar_chart_outlined,
            label: 'Attendance\nReports',
            color: const Color(0xFF0D6B5E),
            onTap: () => onNavigate(LecturerAttendanceReport(user: user)),
          )),
        ]),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(children: [
        Icon(icon, size: 36, color: const Color(0xFFB0BAD0)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D3748))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF8896AB)), textAlign: TextAlign.center),
      ]),
    );
  }
}

// _ScheduleCard — displays a single today's class card.
// Shows a "View Code" button when an active session exists (onViewSession != null),
// allowing the lecturer to jump directly to the live session without going through
// the class list — the primary fix for this screen's active-session navigation.
class _ScheduleCard extends StatelessWidget {
  final ClassScheduleModel schedule;
  final VoidCallback onManage;
  final VoidCallback? onViewSession;
  const _ScheduleCard({required this.schedule, required this.onManage, this.onViewSession});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(children: [
        // Colored top strip — green when session is active, blue otherwise
        Container(
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFF1A3A6B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(schedule.courseName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F2449))),
                const SizedBox(height: 2),
                Text('${schedule.courseCode}  ·  ${schedule.section}',
                  style: const TextStyle(color: Color(0xFF8896AB), fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _Chip(icon: Icons.access_time_outlined, label: '${schedule.startTime} – ${schedule.endTime}'),
              const SizedBox(width: 10),
              _Chip(icon: Icons.place_outlined, label: schedule.venue),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              // "View Code" button — only shown when there is an active session.
              // Navigates directly to LecturerActiveSession to show the attendance code.
              if (onViewSession != null) ...[
                Pressable(
                  onTap: onViewSession,
                  scale: 0.97,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6B5E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.qr_code_outlined, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('View Code',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: Pressable(
                onTap: onManage,
                scale: 0.97,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A6B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('Manage Attendance',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: const Color(0xFF8896AB)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B82))),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
        ]),
      ),
    );
  }
}
