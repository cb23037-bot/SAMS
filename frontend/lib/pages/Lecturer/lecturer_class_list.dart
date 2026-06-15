// lecturer_class_list.dart — Boundary Screen
// Requirement ID : SAMS-PACK-407
// Responsibility : Displays all class schedules assigned to the lecturer and allows
//                  the lecturer to start or resume an attendance session.
//
// Attributes:
//   scheduleList      List<ClassSchedule>
//   selectedSchedule  ClassSchedule
//   navigation        Navigation
//
// Methods:
//   render()                            — Renders lecturer class list interface.
//   loadLecturerSchedules()             — Retrieves schedules assigned to lecturer.
//   startAttendanceSession(schedule_id) — Starts or resumes an attendance session.

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'lecturer_active_session.dart';

class LecturerClassList extends StatefulWidget {
  final UserModel? user;
  const LecturerClassList({super.key, required this.user});

  @override
  State<LecturerClassList> createState() => _LecturerClassListState();
}

class _LecturerClassListState extends State<LecturerClassList> {
  List<ClassScheduleModel> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // loadLecturerSchedules() — SAMS-PACK-407
    _loadSchedules();
  }

  // loadLecturerSchedules() — List<ClassSchedule>
  // SAMS-PACK-407
  // GET lecturer_id from session → CALL LecturerAttendanceController.getAssignedSchedules()
  Future<void> _loadSchedules() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getLecturerSchedules();
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

  // startAttendanceSession(schedule_id) — AttendanceSession
  // SAMS-PACK-407
  // CALL LecturerAttendanceController.startSession(schedule_id)
  // IF session created THEN NAVIGATE to LecturerActiveSession ELSE DISPLAY error
  Future<void> _startSession(ClassScheduleModel schedule) async {
    final res = await ApiService.startSession(schedule.scheduleId);
    if (res['status'] == 201) {
      final session = AttendanceSessionModel.fromJson(res['session']);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => LecturerActiveSession(schedule: schedule, session: session),
      )).then((_) => _loadSchedules());
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Failed to start session'),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // render() — void  (SAMS-PACK-407)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Class Schedules',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedules,
        color: const Color(0xFF1E5BFF),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5BFF)))
          : _schedules.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _schedules.length,
                itemBuilder: (_, i) => _ScheduleItem(
                  schedule: _schedules[i],
                  onStartSession: _startSession,
                  onViewSession: (s, sess) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LecturerActiveSession(schedule: s, session: sess),
                    )).then((_) => _loadSchedules());
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.calendar_today_outlined, size: 52, color: Color(0xFF5B6B86)),
      SizedBox(height: 14),
      Text('No schedules assigned',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF111827))),
      SizedBox(height: 6),
      Text('Contact admin to add class schedules',
        style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
    ]));
  }
}

// _ScheduleItem — renders a single class schedule card with Module 1 style.
// Shows "View Active Session" when an active session exists, "Start Session" otherwise.
class _ScheduleItem extends StatefulWidget {
  final ClassScheduleModel schedule;
  final Future<void> Function(ClassScheduleModel) onStartSession;
  final void Function(ClassScheduleModel, AttendanceSessionModel) onViewSession;
  const _ScheduleItem({
    required this.schedule,
    required this.onStartSession,
    required this.onViewSession,
  });

  @override
  State<_ScheduleItem> createState() => _ScheduleItemState();
}

class _ScheduleItemState extends State<_ScheduleItem> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final s         = widget.schedule;
    final hasActive = s.activeSession != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        // Top accent bar — green when active session exists, blue gradient otherwise
        Container(
          height: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasActive
                ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                : [const Color(0xFF2E6BFF), const Color(0xFF1544D9)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.courseName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text('${s.courseCode}  ·  ${s.className}  ·  ${s.section}',
                  style: const TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
              ])),
              // Active badge
              if (hasActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
                    SizedBox(width: 5),
                    Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _InfoChip(icon: Icons.access_time_outlined, label: '${s.startTime} – ${s.endTime}'),
              _InfoChip(icon: Icons.place_outlined, label: s.venue),
              _InfoChip(icon: Icons.calendar_today_outlined, label: s.scheduleDate),
            ]),
            const SizedBox(height: 14),
            // startAttendanceSession() — SAMS-PACK-407
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _starting ? null : () async {
                  if (hasActive) {
                    widget.onViewSession(s, s.activeSession!);
                  } else {
                    setState(() => _starting = true);
                    await widget.onStartSession(s);
                    if (mounted) setState(() => _starting = false);
                  }
                },
                icon: _starting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(hasActive ? Icons.open_in_new_outlined : Icons.play_arrow_rounded, size: 18),
                label: Text(hasActive ? 'View Active Session' : 'Start Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasActive ? const Color(0xFF22C55E) : const Color(0xFF1E5BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF5B6B86)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
    ]);
  }
}
