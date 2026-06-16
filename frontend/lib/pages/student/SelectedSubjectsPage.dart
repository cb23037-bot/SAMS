import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../app/app_controller.dart';

class SelectedSubjectsPage extends StatefulWidget {
  final List<Subject> selectedSubjects;
  final AppController controller;

  const SelectedSubjectsPage({
    super.key,
    required this.selectedSubjects,
    required this.controller,
  });

  @override
  State<SelectedSubjectsPage> createState() => _SelectedSubjectsPageState();
}

class _SelectedSubjectsPageState extends State<SelectedSubjectsPage> {
  late List<Subject> _subjects;
  bool _isSubmitting = false;
  final Map<int, String> _conflictMap = {};

  @override
  void initState() {
    super.initState();
    _subjects = List.from(widget.selectedSubjects);
    _detectConflicts();
  }

  // Helper to extract all schedules for a subject
  List<_Schedule> _extractSchedules(Subject subject) {
    final schedules = <_Schedule>[];
    
    // Add Lecture Schedule if exists
    if (subject.lectureSchedule != null && subject.lectureSchedule!.isNotEmpty) {
      schedules.addAll(_parseSchedule(subject.lectureSchedule!));
    }
    // Add Lab Schedule if exists
    if (subject.labSchedule != null && subject.labSchedule!.isNotEmpty) {
      schedules.addAll(_parseSchedule(subject.labSchedule!));
    }
    return schedules;
  }

  // Parses format "Monday 09:00-11:00"
  List<_Schedule> _parseSchedule(String schedule) {
    final schedules = <_Schedule>[];
    final parts = schedule.split(' ');
    if (parts.length >= 2) {
      final day = parts[0];
      final timeRange = parts.sublist(1).join(' ');
      final times = timeRange.split('-');
      if (times.length == 2) {
        try {
          schedules.add(_Schedule(
            day: day, 
            startTime: _parseTime(times[0].trim()), 
            endTime: _parseTime(times[1].trim())
          ));
        } catch (_) {}
      }
    }
    return schedules;
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    return parts.length == 2 ? int.parse(parts[0]) * 60 + int.parse(parts[1]) : 0;
  }

  void _detectConflicts() {
    _conflictMap.clear();
    for (int i = 0; i < _subjects.length; i++) {
      final s1 = _extractSchedules(_subjects[i]);
      for (int j = i + 1; j < _subjects.length; j++) {
        final s2 = _extractSchedules(_subjects[j]);
        if (_hasTimeConflict(s1, s2)) {
          _conflictMap[i] = _subjects[j].name;
          _conflictMap[j] = _subjects[i].name;
        }
      }
    }
  }

  bool _hasTimeConflict(List<_Schedule> s1, List<_Schedule> s2) {
    for (final a in s1) {
      for (final b in s2) {
        if (a.day == b.day && (a.startTime < b.endTime && a.endTime > b.startTime)) return true;
      }
    }
    return false;
  }

  // --- UI Methods ---

  Widget _buildSectionCard({
    required String title,
    required String section,
    required String instructor,
    required String schedule,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text('Section $section', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(instructor, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(schedule, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Registration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._subjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subject = entry.value;
            final hasConflict = _conflictMap.containsKey(index);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${subject.code} - ${subject.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setState(() => _subjects.removeAt(index)), icon: const Icon(Icons.delete, color: Colors.red))
                      ],
                    ),
                    if (subject.lectureSection != null)
                      _buildSectionCard(title: 'Lecture', section: subject.lectureSection!, instructor: subject.lecturer ?? '', schedule: subject.lectureSchedule ?? '', color: Colors.blue),
                    if (subject.labSection != null)
                      _buildSectionCard(title: 'Lab', section: subject.labSection!, instructor: subject.labInstructor ?? '', schedule: subject.labSchedule ?? '', color: Colors.purple),
                    if (hasConflict)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Clashes with: ${_conflictMap[index]}', style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ],
                ),
              ),
            );
          }),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () async {
              setState(() => _isSubmitting = true);
              // Submit Logic...
            },
            child: _isSubmitting ? const CircularProgressIndicator() : const Text('Confirm Registration'),
          )
        ],
      ),
    );
  }
}

class _Schedule {
  final String day;
  final int startTime;
  final int endTime;
  _Schedule({required this.day, required this.startTime, required this.endTime});
}