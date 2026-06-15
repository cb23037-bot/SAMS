// student_dashboard.dart — Boundary Screen
// Requirement ID : SAMS-PACK-411
// Responsibility : Displays student dashboard and provides access to attendance submission.
//                  Shows active session notification if a session is available.
//
// Attributes:
//   studentData    User
//   activeSession  AttendanceSession
//   navigation     Navigation
//
// Methods:
//   render()                          — Renders student dashboard interface.
//   checkActiveAttendance(student_id) — Checks active attendance session for student.
//   navigateToAttendanceForm()        — Navigates to student attendance form.

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/animations.dart';
import '../login_screen.dart';
import 'student_class_list.dart';

class StudentDashboard extends StatefulWidget {
  final UserModel user;
  const StudentDashboard({super.key, required this.user});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<ClassScheduleModel> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // checkActiveAttendance() — SAMS-PACK-411
    _load();
  }

  // checkActiveAttendance(student_id) — AttendanceSession
  // SAMS-PACK-411
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getEnrolledSchedules();
      if (res['status'] == 200) {
        setState(() {
          _schedules = (res['schedules'] as List)
              .map((j) => ClassScheduleModel.fromJson(j))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  // logout() — void
  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // navigateToAttendanceForm() — void
  // SAMS-PACK-411
  void _navigate(Widget page) {
    Navigator.push(context, SlideUpRoute(page: page)).then((_) => _load());
  }

  // render() — void  (SAMS-PACK-411)
  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first;
    final activeNow = _schedules.where((s) => s.activeSession != null && !s.alreadySubmitted).toList();
    final submitted = _schedules.where((s) => s.alreadySubmitted).length;
    final enrolled  = _schedules.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
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
                        Text('Student Portal',
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
                      Text(widget.user.studentId ?? widget.user.email,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: _loading ? _Skeleton() : _Body(
                  activeNow: activeNow,
                  enrolled: enrolled,
                  submitted: submitted,
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
class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: 76, borderRadius: 18)),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(width: double.infinity, height: 76, borderRadius: 18)),
      ]),
      SizedBox(height: 20),
      ShimmerBox(width: 90, height: 16, borderRadius: 6),
      SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 72, borderRadius: 18),
    ]);
  }
}

// ─── Loaded body ──────────────────────────────────────────────────────────────
// render() — void  (SAMS-PACK-411)
class _Body extends StatelessWidget {
  final List<ClassScheduleModel> activeNow;
  final int enrolled;
  final int submitted;
  final UserModel user;
  final void Function(Widget) onNavigate;

  const _Body({
    required this.activeNow,
    required this.enrolled,
    required this.submitted,
    required this.user,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return StaggerList(
      children: [
        // Active session banner — green-tinted card
        // navigateToAttendanceForm() — SAMS-PACK-411
        if (activeNow.isNotEmpty) ...[
          FadeSlideIn(
            duration: kDurationMedium,
            child: _ActiveBanner(
              session: activeNow.first,
              onTap: () => onNavigate(StudentClassList(user: user)),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Stats row
        Row(children: [
          _StatCard(
            icon: Icons.menu_book_outlined,
            label: 'Enrolled',
            value: '$enrolled',
            color: const Color(0xFF1E5BFF),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Attended',
            value: '$submitted',
            color: const Color(0xFF22C55E),
          ),
        ]),

        const SizedBox(height: 20),

        const Text('My Classes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),

        const SizedBox(height: 12),

        // Submit Attendance action card — navigateToAttendanceForm() — SAMS-PACK-411
        InkWell(
          onTap: () => onNavigate(StudentClassList(user: user)),
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
                decoration: const BoxDecoration(color: Color(0xFF1E5BFF), shape: BoxShape.circle),
                child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Submit Attendance',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF111827)))),
              // Badge — count of active unsubmitted sessions
              if (activeNow.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${activeNow.length}',
                    style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12,
                        fontWeight: FontWeight.w700)),
                )
              else
                const Icon(Icons.chevron_right, color: Color(0xFF5B6B86)),
            ]),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Active session banner ────────────────────────────────────────────────────
// Shown when there is at least one active session the student has not submitted.
class _ActiveBanner extends StatelessWidget {
  final ClassScheduleModel session;
  final VoidCallback onTap;
  const _ActiveBanner({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Active Session',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF22C55E))),
              const SizedBox(height: 2),
              Text(session.courseName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827))),
              Text('${session.courseCode}  ·  ${session.section}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Attendance Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDF6)),
          boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86))),
          ]),
        ]),
      ),
    );
  }
}
