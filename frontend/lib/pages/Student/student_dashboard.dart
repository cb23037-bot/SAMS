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
    _load();
  }

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

  void _navigate(Widget page) {
    Navigator.push(context, SlideUpRoute(page: page)).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first;
    final activeNow = _schedules.where((s) => s.activeSession != null && !s.alreadySubmitted).toList();
    final submitted = _schedules.where((s) => s.alreadySubmitted).length;
    final enrolled  = _schedules.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1A3A6B),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 170,
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
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                                  fontSize: 16, letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 16),
                          Text('${_greeting()}, $firstName',
                            style: const TextStyle(color: Colors.white, fontSize: 22,
                                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(widget.user.studentId ?? widget.user.email,
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

// ─── Loading skeleton ─────────────────────────────────────────────────────────
class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: 76, borderRadius: 14)),
        SizedBox(width: 12),
        Expanded(child: ShimmerBox(width: double.infinity, height: 76, borderRadius: 14)),
      ]),
      SizedBox(height: 20),
      ShimmerBox(width: 90, height: 16, borderRadius: 6),
      SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 72, borderRadius: 14),
    ]);
  }
}

// ─── Loaded body ──────────────────────────────────────────────────────────────
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
        // Active session banner
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
            color: const Color(0xFF1A3A6B),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Attended',
            value: '$submitted',
            color: const Color(0xFF0D6B5E),
          ),
        ]),

        const SizedBox(height: 20),

        const Text('My Classes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),

        const SizedBox(height: 12),

        _MenuTile(
          icon: Icons.fact_check_outlined,
          title: 'Submit Attendance',
          subtitle: 'View enrolled classes and submit attendance',
          badgeCount: activeNow.length,
          onTap: () => onNavigate(StudentClassList(user: user)),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Active session banner ────────────────────────────────────────────────────
class _ActiveBanner extends StatelessWidget {
  final ClassScheduleModel session;
  final VoidCallback onTap;
  const _ActiveBanner({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB2DFDB)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0D6B5E),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Active Session',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0D6B5E))),
              const SizedBox(height: 2),
              Text(session.courseName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748))),
              Text('${session.courseCode}  ·  ${session.section}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B82))),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Pressable(
            onTap: onTap,
            scale: 0.97,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF0D6B5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('Submit Attendance Now',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
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
      child: Pressable(
        scale: 0.97,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF2)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8896AB))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon, required this.title, required this.subtitle,
    required this.badgeCount, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF2)),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1A3A6B), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                  color: Color(0xFF0F2449))),
            const SizedBox(height: 2),
            Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
          ])),
          if (badgeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D6B5E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700)),
            )
          else
            const Icon(Icons.chevron_right, color: Color(0xFFB0BAD0)),
        ]),
      ),
    );
  }
}
