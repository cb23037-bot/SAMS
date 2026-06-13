import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'lecturer_class_list.dart';
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
    _loadTodaySchedule();
  }

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
            // Header
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's classes header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's Classes",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => LecturerClassList(user: widget.user))),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1A3A6B),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: const Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: Color(0xFF1A3A6B)),
                      ))
                    else if (_todaySchedules.isEmpty)
                      const _EmptyCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'No classes today',
                        subtitle: 'Your schedule is clear for today.',
                      )
                    else
                      ..._todaySchedules.map((s) => _ScheduleCard(
                        schedule: s,
                        onManage: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LecturerClassList(user: widget.user))),
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
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LecturerClassList(user: widget.user))),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionTile(
                        icon: Icons.bar_chart_outlined,
                        label: 'Attendance\nReports',
                        color: const Color(0xFF0D6B5E),
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LecturerAttendanceReport(user: widget.user))),
                      )),
                    ]),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

class _ScheduleCard extends StatelessWidget {
  final ClassScheduleModel schedule;
  final VoidCallback onManage;
  const _ScheduleCard({required this.schedule, required this.onManage});

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
        // Colored top strip
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onManage,
                child: const Text('Manage Attendance'),
              ),
            ),
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
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
      ),
    );
  }
}
