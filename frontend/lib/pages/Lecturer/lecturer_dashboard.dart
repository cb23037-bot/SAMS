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
  void _navigate(Widget page) {
    Navigator.push(context, SlideUpRoute(page: page));
  }

  // render() — void
  // SAMS-PACK-406
  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadTodaySchedule,
        color: const Color(0xFF1E5BFF),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Brand + logout row
                  Row(children: [
                    _MiniBrandMark(),
                    const SizedBox(width: 10),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lecturer Portal',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF111827))),
                        Text('Attendance Management',
                          style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
                      ],
                    )),
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
                      tooltip: 'Sign out',
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Welcome card — gradient blue
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_greeting()}, $firstName',
                        style: const TextStyle(color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_formatDate(DateTime.now()),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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

// ─── Mini brand mark ──────────────────────────────────────────────────────────
class _MiniBrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school, color: Color(0xFF1E5BFF), size: 22),
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
      ShimmerBox(width: double.infinity, height: 120, borderRadius: 18),
      SizedBox(height: 10),
      ShimmerBox(width: double.infinity, height: 120, borderRadius: 18),
      SizedBox(height: 24),
      ShimmerBox(width: 110, height: 16, borderRadius: 6),
      SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 72, borderRadius: 18),
      SizedBox(height: 10),
      ShimmerBox(width: double.infinity, height: 72, borderRadius: 18),
    ]);
  }
}

// ─── Loaded body ──────────────────────────────────────────────────────────────
// render() — void  (SAMS-PACK-406)
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
        // Section heading — Today's Classes
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Today's Classes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          Pressable(
            onTap: () => onNavigate(LecturerClassList(user: user)),
            scale: 0.95,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('View all',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E5BFF))),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Schedule cards or empty state
        if (schedules.isEmpty)
          _EmptyCard(
            icon: Icons.calendar_today_outlined,
            title: 'No classes today',
            subtitle: 'Your schedule is clear for today.',
          )
        else
          // navigateToClassList() / onViewSession() — SAMS-PACK-406
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

        // Quick Actions section
        const Text('Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 12),

        _ActionCard(
          icon: Icons.fact_check_outlined,
          title: 'Manage Classes',
          color: const Color(0xFF1E5BFF),
          onTap: () => onNavigate(LecturerClassList(user: user)),
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.bar_chart_outlined,
          title: 'Attendance Reports',
          color: const Color(0xFF22C55E),
          onTap: () => onNavigate(LecturerAttendanceReport(user: user)),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Action card ──────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDF6)),
          boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF111827))),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFF5B6B86)),
        ]),
      ),
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        Icon(icon, size: 36, color: const Color(0xFF5B6B86)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Schedule card ────────────────────────────────────────────────────────────
// Shows a "View Code" button when an active session exists (onViewSession != null).
class _ScheduleCard extends StatelessWidget {
  final ClassScheduleModel schedule;
  final VoidCallback onManage;
  final VoidCallback? onViewSession;
  const _ScheduleCard({required this.schedule, required this.onManage, this.onViewSession});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        // Top accent bar
        Container(
          height: 4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(schedule.courseName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
            const SizedBox(height: 2),
            Text('${schedule.courseCode}  ·  ${schedule.section}',
              style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              _Chip(icon: Icons.access_time_outlined, label: '${schedule.startTime} – ${schedule.endTime}'),
              const SizedBox(width: 10),
              _Chip(icon: Icons.place_outlined, label: schedule.venue),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              // "View Code" — only shown when there is an active session
              if (onViewSession != null) ...[
                Pressable(
                  onTap: onViewSession,
                  scale: 0.97,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
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
                    gradient: const LinearGradient(colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)]),
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
      Icon(icon, size: 14, color: const Color(0xFF5B6B86)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
    ]);
  }
}
