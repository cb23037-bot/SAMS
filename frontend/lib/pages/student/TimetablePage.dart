import 'package:flutter/material.dart';

import '../../models/subject.dart';

class TimetablePage extends StatelessWidget {
  final List<Subject> selectedSubjects;

  const TimetablePage({
    super.key,
    required this.selectedSubjects,
  });

  static const List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  static const List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
  ];

  @override
  Widget build(BuildContext context) {
    final timetableData = _buildTimetable();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTimetableGrid(timetableData),
          ),
        ),
      ),
    );
  }

  Widget _buildTimetableGrid(Map<String, Map<String, List<_ScheduleEvent>>> timetableData) {
    return IntrinsicWidth(
      child: Column(
        children: [
          // Header with day names
          IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      'Time',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
                ..._days.map((day) {
                  return SizedBox(
                    width: 140,
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const Divider(height: 1),
          // Time slots and subjects
          ..._timeSlots.map((time) {
            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 120,
                        child: Center(
                          child: Text(
                            time,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                      ..._days.map((day) {
                        final events = timetableData[day]?[time] ?? [];
                        return SizedBox(
                          width: 140,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                right: const BorderSide(color: Color(0xFFE2E8F0)),
                                bottom: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: events.isNotEmpty
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: events
                                        .map((event) => _SubjectEventCard(event: event))
                                        .toList(),
                                  )
                                : const SizedBox.expand(),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Map<String, Map<String, List<_ScheduleEvent>>> _buildTimetable() {
    final timetable = <String, Map<String, List<_ScheduleEvent>>>{};

    // Initialize timetable structure
    for (final day in _days) {
      timetable[day] = {};
      for (final time in _timeSlots) {
        timetable[day]![time] = [];
      }
    }

    // Populate with subject schedules
    for (final subject in selectedSubjects) {
      // Process lecture schedule
      if (subject.lectureSchedule != null && subject.lectureSchedule!.isNotEmpty) {
        _addScheduleToTimetable(
          timetable,
          subject.lectureSchedule!,
          subject.code,
          subject.lecturer,
          'Lecture',
          Colors.blue,
        );
      }

      // Process lab schedule
      if (subject.labSchedule != null && subject.labSchedule!.isNotEmpty) {
        _addScheduleToTimetable(
          timetable,
          subject.labSchedule!,
          subject.code,
          subject.labInstructor,
          'Lab',
          Colors.purple,
        );
      }
    }

    return timetable;
  }

  void _addScheduleToTimetable(
    Map<String, Map<String, List<_ScheduleEvent>>> timetable,
    String schedule,
    String subjectCode,
    String? instructor,
    String type,
    Color color,
  ) {
    final parts = schedule.split(' ');
    if (parts.length < 2) return;

    final day = parts[0];
    final timeRange = parts.sublist(1).join(' ');
    final times = timeRange.split('-');

    if (times.length != 2 || !_days.contains(day)) return;

    final startTime = times[0].trim();
    final endTime = times[1].trim();

    final startIndex = _timeSlots.indexOf(startTime);
    final endIndex = _timeSlots.indexOf(endTime);

    if (startIndex >= 0 && endIndex > startIndex) {
      for (int i = startIndex; i < endIndex; i++) {
        final timeSlot = _timeSlots[i];
        timetable[day]![timeSlot]!.add(
          _ScheduleEvent(
            subjectCode: subjectCode,
            instructor: instructor,
            type: type,
            color: color,
            isStart: i == startIndex,
            isEnd: i == endIndex - 1,
            durationHours: endIndex - startIndex,
          ),
        );
      }
    }
  }
}

class _ScheduleEvent {
  final String subjectCode;
  final String? instructor;
  final String type;
  final Color color;
  final bool isStart;
  final bool isEnd;
  final int durationHours;

  _ScheduleEvent({
    required this.subjectCode,
    required this.instructor,
    required this.type,
    required this.color,
    required this.isStart,
    required this.isEnd,
    required this.durationHours,
  });
}

class _SubjectEventCard extends StatelessWidget {
  final _ScheduleEvent event;

  const _SubjectEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    if (!event.isStart) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: event.color.withOpacity(0.2),
        border: Border.all(color: event.color),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            event.subjectCode,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: event.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            event.type,
            style: TextStyle(fontSize: 9, color: event.color),
          ),
          if (event.instructor != null)
            Text(
              event.instructor!,
              style: const TextStyle(fontSize: 8, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
