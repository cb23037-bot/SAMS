import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/class_schedule.dart';
import 'lecturer_attendance_record.dart';
import 'lecturer_attendance_report.dart';
import 'lecturer_active_session.dart';

/// Lists the class schedules assigned to the lecturer and lets them open a
/// class to start/manage an attendance session.
class LecturerAttendancePage extends StatefulWidget {
  const LecturerAttendancePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LecturerAttendancePage> createState() => _LecturerAttendancePageState();
}

class _LecturerAttendancePageState extends State<LecturerAttendancePage> {
  late Future<List<ClassScheduleModel>> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _scheduleFuture = loadLecturerSchedules();
  }

  /// SAMS-PACK-407: loadLecturerSchedules()
  /// Retrieves all class schedules assigned to the authenticated lecturer.
  /// Returns: List<ClassSchedule> — the lecturer's schedule list.
  Future<List<ClassScheduleModel>> loadLecturerSchedules() {
    return widget.controller.apiService.getLecturerClassSchedules(
      token: widget.controller.token!,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _scheduleFuture = loadLecturerSchedules();
    });
    await _scheduleFuture;
  }

  /// SAMS-PACK-407: startAttendanceSession(schedule_id)
  /// Navigates to the active session page for the selected schedule, which
  /// starts or resumes an AttendanceSession for that class.
  /// Returns: AttendanceSession — via the active session page.
  Future<void> startAttendanceSession(ClassScheduleModel schedule) async {
    final closedSessionId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => LecturerAttendanceSessionPage(
          controller: widget.controller,
          schedule: schedule,
        ),
      ),
    );
    _refresh();
    // Step 14: If the session was just closed, prompt the lecturer to view the record.
    if (closedSessionId != null && mounted) {
      final view = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session Closed'),
          content: const Text('The attendance session has been closed. Would you like to view the attendance record?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Later')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('View Attendance Record')),
          ],
        ),
      );
      if (view == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LecturerAttendanceRecordPage(
              controller: widget.controller,
              sessionId: closedSessionId,
              schedule: schedule,
            ),
          ),
        );
      }
    }
  }

  /// SAMS-PACK-407: render()
  /// Renders the lecturer class list interface — the main Scaffold with
  /// the schedule list and navigation to session management.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Manage Attendance',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Attendance Report',
            icon: const Icon(Icons.bar_chart_outlined, color: Color(0xFF111827)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LecturerAttendanceReportPage(controller: widget.controller),
              ),
            ),
          ),
        ],
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
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF5B6B86)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: OutlinedButton(onPressed: _refresh, child: const Text('Retry'))),
                ],
              );
            }

            final schedules = snapshot.data ?? [];
            if (schedules.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'You have no class schedules yet.',
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
                    onTap: () => startAttendanceSession(schedule),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActiveSession = schedule.activeSession?.isActive ?? false;

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
                      color: Color(0xFF3B82F6),
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
                          'Section ${schedule.section} • ${schedule.enrolledCount ?? 0} students',
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
                  color: (hasActiveSession ? const Color(0xFF22C55E) : const Color(0xFF8A96A8))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasActiveSession ? Icons.podcasts : Icons.play_circle_outline,
                      size: 14,
                      color: hasActiveSession ? const Color(0xFF22C55E) : const Color(0xFF8A96A8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasActiveSession ? 'Session Active' : 'Tap to Start Session',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: hasActiveSession ? const Color(0xFF22C55E) : const Color(0xFF8A96A8),
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
}
