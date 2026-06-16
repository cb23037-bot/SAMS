import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../models/class_schedule.dart';
// Import your new approval list page here
import 'SubjectApprovalListPage.dart';
import 'lecturer_class_list.dart';

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  /// SAMS-PACK-406: loadTodaySchedule() — loads today's class schedule for the lecturer.
  List<ClassScheduleModel> _todaySchedules = [];
  bool _isLoadingSchedules = false;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
  }

  /// SAMS-PACK-406: loadTodaySchedule()
  /// Fetches the lecturer's class schedules and filters to those scheduled today.
  Future<void> _loadTodaySchedule() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final allSchedules = await widget.controller.apiService.getLecturerClassSchedules(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      final today = DateTime.now();
      final todayDate = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      setState(() {
        _todaySchedules = allSchedules.where((s) => s.scheduleDate == todayDate).toList();
      });
    } catch (_) {
      // Silent fail — today's class card is optional UI
    } finally {
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  /// SAMS-PACK-406: navigateToClassList() — opens the Manage Attendance page.
  void _navigateToClassList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LecturerAttendancePage(controller: widget.controller)),
    );
  }

  Future<void> _logout() async {
    await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const _MiniBrandMark(),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lecturer Portal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text('Academic System', style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Color(0xFFFF3B30))
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Welcome Card
              _WelcomeCard(user: user, role: 'Lecturer'),

              const SizedBox(height: 24),

              // SAMS-PACK-406: Today's Class card — shown when schedule exists for today.
              if (_isLoadingSchedules)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (_todaySchedules.isNotEmpty) ...[
                const Text("Today's Classes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 10),
                ..._todaySchedules.map((schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TodayClassCard(schedule: schedule, onTap: _navigateToClassList),
                )),
                const SizedBox(height: 14),
              ],

              const Text('Quick Actions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // Navigation to Approval Workflow
              _ActionCard(
                title: 'Registration Approvals',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubjectApprovalListPage(controller: widget.controller))
                ),
              ),
              const SizedBox(height: 12),

              // Navigation to Class Attendance Management
              _ActionCard(
                title: 'Manage Student Attendance',
                icon: Icons.qr_code_scanner_outlined,
                color: const Color(0xFF2E6BFF),
                onTap: _navigateToClassList,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card shown on the lecturer dashboard for each class scheduled today.
class _TodayClassCard extends StatelessWidget {
  const _TodayClassCard({required this.schedule, required this.onTap});

  final ClassScheduleModel schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = schedule.activeSession?.isActive ?? false;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBDD4FF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Color(0xFF2E6BFF), shape: BoxShape.circle),
              child: const Icon(Icons.class_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${schedule.courseCode} - ${schedule.courseName}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${schedule.startTime} - ${schedule.endTime}  •  ${schedule.venue}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hasActive ? const Color(0xFF22C55E) : const Color(0xFF2E6BFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                hasActive ? 'Active' : 'Start',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared Theme Widgets ---

class _MiniBrandMark extends StatelessWidget {
  const _MiniBrandMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: const Color(0xFFF1F6FF), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(6),
        child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user, required this.role});
  final dynamic user;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome Back,', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            Text(role, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
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
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            ],
          ),
        ),
      );
}