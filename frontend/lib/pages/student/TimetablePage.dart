import 'package:flutter/material.dart';
import '../../models/subject.dart';

class TimetablePage extends StatelessWidget {
  final List<Subject> selectedSubjects;

  const TimetablePage({super.key, required this.selectedSubjects});

  static const List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  static const List<String> _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
  ];

  @override
  Widget build(BuildContext context) {
    final timetableData = _buildTimetable();
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
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
    return Column(
      children: [
        Row(children: [const SizedBox(width: 80), ..._days.map((day) => SizedBox(width: 140, child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)))))]),
        const Divider(),
        ..._timeSlots.map((time) => Row(
          children: [
            SizedBox(width: 80, height: 120, child: Center(child: Text(time, style: const TextStyle(color: Colors.grey)))),
            ..._days.map((day) {
              final events = timetableData[day]?[time] ?? [];
              return Container(
                width: 140,
                height: 120,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFE2E8F0)), bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                // Stack allows the event card to render over the bottom border without overflowing the cell
                child: Stack(
                  clipBehavior: Clip.none,
                  children: events.map((e) => _SubjectEventCard(event: e)).toList(),
                ),
              );
            }),
          ],
        )),
      ],
    );
  }

  Map<String, Map<String, List<_ScheduleEvent>>> _buildTimetable() {
    final Map<String, Map<String, List<_ScheduleEvent>>> timetable = {for (var d in _days) d: {for (var t in _timeSlots) t: <_ScheduleEvent>[]}};
    for (final subject in selectedSubjects) {
      final lSch = subject.lectureSchedule ?? (subject.lectureSections.isNotEmpty ? subject.lectureSections.first.schedule : null);
      final lbSch = subject.labSchedule ?? (subject.labSections.isNotEmpty ? subject.labSections.first.schedule : null);
      if (lSch != null) _addSchedule(timetable, lSch, subject.code, subject.lecturer, 'Lecture', Colors.blue);
      if (lbSch != null) _addSchedule(timetable, lbSch, subject.code, subject.labInstructor, 'Lab', Colors.purple);
    }
    return timetable;
  }

  void _addSchedule(Map<String, Map<String, List<_ScheduleEvent>>> timetable, String sch, String code, String? inst, String type, Color color) {
    String day = sch.split(' ')[0].toLowerCase();
    String? matchedDay = _days.firstWhere((d) => d.toLowerCase().startsWith(day), orElse: () => '');
    if (matchedDay.isEmpty) return;

    String timePart = sch.substring(sch.indexOf(' ') + 1);
    String convertTo24(String time) {
      time = time.trim().toUpperCase();
      int hour = int.parse(time.split(':')[0]);
      int min = int.parse(time.split(':')[1].replaceAll(RegExp(r'[A-Z]'), ''));
      if (time.contains('PM') && hour < 12) hour += 12;
      if (time.contains('AM') && hour == 12) hour = 0;
      return "${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}";
    }

    final times = timePart.split('-');
    final startIdx = _timeSlots.indexOf(convertTo24(times[0]));
    final endIdx = _timeSlots.indexOf(convertTo24(times[1]));

    if (startIdx >= 0 && endIdx > startIdx) {
      timetable[matchedDay]![_timeSlots[startIdx]]!.add(_ScheduleEvent(
        subjectCode: code, instructor: inst, type: type, color: color,
        isStart: true, durationHours: endIdx - startIdx,
      ));
    }
  }
}

class _ScheduleEvent {
  final String subjectCode, type;
  final String? instructor;
  final Color color;
  final bool isStart;
  final int durationHours;
  _ScheduleEvent({required this.subjectCode, required this.type, this.instructor, required this.color, required this.isStart, required this.durationHours});
}

class _SubjectEventCard extends StatelessWidget {
  final _ScheduleEvent event;
  const _SubjectEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    // Only render the card if it's the start of the event
    if (!event.isStart) return const SizedBox.shrink();
    
    return Container(
      height: (event.durationHours * 120.0) - 2,
      width: 138,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: event.color.withValues(alpha: 0.2), border: Border.all(color: event.color), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.subjectCode, style: TextStyle(fontWeight: FontWeight.bold, color: event.color, fontSize: 10)),
        Text(event.type, style: TextStyle(fontSize: 8, color: event.color)),
      ]),
    );
  }
}