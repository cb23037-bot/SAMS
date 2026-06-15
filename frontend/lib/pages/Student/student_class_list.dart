// student_class_list.dart — Boundary Screen
// Requirement ID : SAMS-PACK-413
// Responsibility : Displays all classes the student is enrolled in and provides
//                  a way to navigate to the attendance submission form.
//
// Attributes:
//   enrolledClasses  List<ClassSchedule>
//   navigation       Navigation
//
// Methods:
//   render()                    — Renders the list of enrolled classes.
//   loadEnrolledClasses()       — Loads enrolled class schedules from the API.
//   selectClass(schedule)       — Selects a class and navigates to attendance form.
//   navigateToAttendanceForm()  — Navigates to the student attendance form screen.

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'student_attendance_form.dart';

class StudentClassList extends StatefulWidget {
  final UserModel user;
  const StudentClassList({super.key, required this.user});

  @override
  State<StudentClassList> createState() => _StudentClassListState();
}

class _StudentClassListState extends State<StudentClassList> {
  List<ClassScheduleModel> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // loadEnrolledClasses() — SAMS-PACK-413
    _load();
  }

  // loadEnrolledClasses() — void
  // SAMS-PACK-413
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

  // render() — void  (SAMS-PACK-413)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('My Classes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1E5BFF),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5BFF)))
          : _schedules.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _schedules.length,
                // selectClass(schedule) — SAMS-PACK-413: navigateToAttendanceForm()
                itemBuilder: (_, i) => _ClassCard(
                  schedule: _schedules[i],
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StudentAttendanceForm(
                      user: widget.user, schedule: _schedules[i])
                  )).then((_) => _load()),
                ),
              ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.school_outlined, size: 52, color: Color(0xFF5B6B86)),
      SizedBox(height: 14),
      Text('No classes found',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF111827))),
      SizedBox(height: 6),
      Text('You are not enrolled in any classes yet',
        style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
    ]));
  }
}

// ─── Class card ───────────────────────────────────────────────────────────────
// render() — void  (SAMS-PACK-413)
// selectClass(schedule) algorithm:
//   IF alreadySubmitted   → show "Submitted" confirmation row (no button)
//   ELSE IF activeSession → show "Submit Attendance" button → navigateToAttendanceForm()
//   ELSE                  → show "No active session" notice
class _ClassCard extends StatelessWidget {
  final ClassScheduleModel schedule;
  final VoidCallback onTap;
  const _ClassCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasActive = schedule.activeSession != null;
    final submitted = schedule.alreadySubmitted;

    // Accent colour: green = submitted, blue = active session, grey = no session
    final Color accentColor;
    if (submitted) {
      accentColor = const Color(0xFF22C55E);
    } else if (hasActive) {
      accentColor = const Color(0xFF1E5BFF);
    } else {
      accentColor = const Color(0xFF5B6B86);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: [
        // Top colour bar — indicates session status
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(schedule.courseName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Text('${schedule.courseCode}  ·  ${schedule.section}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
              ])),
              const SizedBox(width: 10),
              // Status pill — Module 1 style
              if (submitted)
                _StatusPill(label: 'Submitted', color: const Color(0xFF22C55E))
              else if (hasActive)
                _StatusPill(label: 'Active', color: const Color(0xFF1E5BFF)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _InfoChip(icon: Icons.access_time_outlined, label: '${schedule.startTime} – ${schedule.endTime}'),
              _InfoChip(icon: Icons.place_outlined, label: schedule.venue),
              _InfoChip(icon: Icons.calendar_today_outlined, label: schedule.scheduleDate),
            ]),
            const SizedBox(height: 14),

            // Action row
            if (submitted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 16),
                  SizedBox(width: 8),
                  Text('Attendance submitted for this session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF22C55E))),
                ]),
              )
            else if (hasActive)
              // navigateToAttendanceForm() — SAMS-PACK-413
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Submit Attendance',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EDF6)),
                ),
                child: const Row(children: [
                  Icon(Icons.schedule_outlined, color: Color(0xFF5B6B86), size: 16),
                  SizedBox(width: 8),
                  Text('No active session for this class',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Status pill — Module 1 style ─────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────
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
