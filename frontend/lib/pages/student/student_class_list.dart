import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/class_schedule.dart';
import 'student_attendance_form.dart';

/// Lists the classes the student is enrolled in and lets them open a class
/// that currently has an active attendance session to mark their attendance.
class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  late Future<List<ClassScheduleModel>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = loadEnrolledClasses();
  }

  /// SAMS-PACK-413: loadEnrolledClasses()
  /// Retrieves all class schedules for the classes the student is enrolled in.
  /// Called on page load and after returning from the attendance form.
  /// Returns: List<ClassSchedule> — the student's enrolled class schedules.
  Future<List<ClassScheduleModel>> loadEnrolledClasses() {
    return widget.controller.apiService.getStudentClassSchedules(
      token: widget.controller.token!,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _scheduleFuture = loadEnrolledClasses();
    });
    await _scheduleFuture;
  }

  /// SAMS-PACK-413: selectClass(schedule_id)
  /// Selects the class schedule the student tapped and navigates to the
  /// attendance submission form for that class.
  /// Uses the already-resolved snapshot data passed in from the list builder
  /// so no async gap occurs before the Navigator call.
  /// Returns: void
  void selectClass(ClassScheduleModel schedule) {
    navigateToAttendanceForm(schedule.scheduleId, schedule: schedule);
  }

  /// SAMS-PACK-413: navigateToAttendanceForm(schedule_id)
  /// Navigates to the attendance submission form for the selected class schedule.
  /// Refreshes the class list when returning so the session status stays current.
  /// [schedule] must be provided so no async gap occurs before the Navigator call.
  /// Returns: void
  Future<void> navigateToAttendanceForm(int scheduleId, {required ClassScheduleModel schedule}) async {
    final marked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StudentAttendanceSubmitPage(
          controller: widget.controller,
          schedule: schedule,
        ),
      ),
    );
    if (marked == true) _refresh();
  }

  /// SAMS-PACK-413: render()
  /// Renders the enrolled class list interface — a scrollable list of class
  /// schedule cards with session status badges and tap-to-attend interaction.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ClassScheduleModel>>(
          future: _scheduleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString().replaceAll('Exception: ', ''),
                onRetry: _refresh,
              );
            }

            final schedules = snapshot.data ?? [];
            if (schedules.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'You are not enrolled in any class yet.',
                      style: TextStyle(color: Color(0xFF5B6B86)),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ClassScheduleCard(
                    schedule: schedule,
                    onTap: (schedule.hasActiveSession && !schedule.alreadySubmitted)
                        ? () => navigateToAttendanceForm(schedule.scheduleId, schedule: schedule)
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ClassScheduleCard extends StatelessWidget {
  const _ClassScheduleCard({required this.schedule, required this.onTap});

  final ClassScheduleModel schedule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final _StatusInfo status = _statusFor(schedule);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${schedule.courseCode} - ${schedule.courseName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Section ${schedule.section} • ${schedule.lecturerName ?? 'N/A'}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Color(0xFF5B6B86)),
                  const SizedBox(width: 6),
                  Text(
                    '${schedule.day}, ${schedule.startTime} - ${schedule.endTime}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF5B6B86)),
                  const SizedBox(width: 6),
                  Text(
                    schedule.venue,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 14, color: status.color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        status.label,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status.color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusInfo _statusFor(ClassScheduleModel schedule) {
    if (schedule.alreadySubmitted) {
      return _StatusInfo('Attendance Marked', Icons.check_circle, const Color(0xFF22C55E));
    }
    if (schedule.hasActiveSession) {
      return _StatusInfo('Session Active - Tap to Mark', Icons.touch_app, const Color(0xFF2E6BFF));
    }
    return _StatusInfo('No Active Session / Attendance Session has ended.', Icons.schedule_outlined, const Color(0xFF8A96A8));
  }
}

class _StatusInfo {
  const _StatusInfo(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5B6B86))),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
