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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(title: const Text('My Classes')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF1A3A6B),
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A3A6B)))
          : _schedules.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _schedules.length,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.school_outlined, size: 52, color: Color(0xFFB0BAD0)),
      SizedBox(height: 14),
      Text('No classes found',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF2D3748))),
      SizedBox(height: 6),
      Text('You are not enrolled in any classes yet',
        style: TextStyle(color: Color(0xFF8896AB), fontSize: 13)),
    ]));
  }
}

class _ClassCard extends StatelessWidget {
  final ClassScheduleModel schedule;
  final VoidCallback onTap;
  const _ClassCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasActive  = schedule.activeSession != null;
    final submitted  = schedule.alreadySubmitted;

    final Color accentColor;
    if (submitted) {
      accentColor = const Color(0xFF0D6B5E);
    } else if (hasActive) {
      accentColor = const Color(0xFF1A3A6B);
    } else {
      accentColor = const Color(0xFFB0BAD0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(schedule.courseName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F2449))),
                const SizedBox(height: 3),
                Text('${schedule.courseCode}  ·  ${schedule.section}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8896AB))),
              ])),
              const SizedBox(width: 10),
              if (submitted)
                const _Pill(label: 'Submitted', color: Color(0xFF0D6B5E))
              else if (hasActive)
                const _Pill(label: 'Active', color: Color(0xFF1A3A6B)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 6, children: [
              _InfoChip(icon: Icons.access_time_outlined, label: '${schedule.startTime} – ${schedule.endTime}'),
              _InfoChip(icon: Icons.place_outlined, label: schedule.venue),
              _InfoChip(icon: Icons.calendar_today_outlined, label: schedule.scheduleDate),
            ]),
            const SizedBox(height: 14),

            if (submitted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF0D6B5E), size: 16),
                  SizedBox(width: 8),
                  Text('Attendance submitted for this session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                        color: Color(0xFF0D6B5E))),
                ]),
              )
            else if (hasActive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A6B),
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text('Submit Attendance'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.schedule_outlined, color: Color(0xFFB0BAD0), size: 16),
                  SizedBox(width: 8),
                  Text('No active session for this class',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8896AB))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 6, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
      Icon(icon, size: 13, color: const Color(0xFF8896AB)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B82))),
    ]);
  }
}
