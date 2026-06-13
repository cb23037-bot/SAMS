import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../app/app_controller.dart';
import '../../services/api_service.dart';

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
  Map<int, String> _conflictMap = {};

  @override
  void initState() {
    super.initState();
    _subjects = List.from(widget.selectedSubjects);
    _detectConflicts();
  }

  void _detectConflicts() {
    _conflictMap.clear();
    
    for (int i = 0; i < _subjects.length; i++) {
      final subject1 = _subjects[i];
      final schedules1 = _extractSchedules(subject1);
      
      for (int j = i + 1; j < _subjects.length; j++) {
        final subject2 = _subjects[j];
        final schedules2 = _extractSchedules(subject2);
        
        if (_hasTimeConflict(schedules1, schedules2)) {
          _conflictMap[i] = '${subject2.name}';
          _conflictMap[j] = '${subject1.name}';
        }
      }
    }
  }

  List<_Schedule> _extractSchedules(Subject subject) {
    final schedules = <_Schedule>[];
    
    if (subject.lectureSchedule != null && subject.lectureSchedule!.isNotEmpty) {
      schedules.addAll(_parseSchedule(subject.lectureSchedule!));
    }
    if (subject.labSchedule != null && subject.labSchedule!.isNotEmpty) {
      schedules.addAll(_parseSchedule(subject.labSchedule!));
    }
    
    return schedules;
  }

  List<_Schedule> _parseSchedule(String schedule) {
    final schedules = <_Schedule>[];
    final parts = schedule.split(' ');
    
    if (parts.length >= 2) {
      final day = parts[0];
      final timeRange = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final times = timeRange.split('-');
      
      if (times.length == 2) {
        try {
          final startTime = _parseTime(times[0].trim());
          final endTime = _parseTime(times[1].trim());
          schedules.add(_Schedule(day: day, startTime: startTime, endTime: endTime));
        } catch (e) {
          // Invalid time format
        }
      }
    }
    
    return schedules;
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length == 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }

  bool _hasTimeConflict(List<_Schedule> schedules1, List<_Schedule> schedules2) {
    for (final s1 in schedules1) {
      for (final s2 in schedules2) {
        if (s1.day == s2.day) {
          if ((s1.startTime < s2.endTime && s1.endTime > s2.startTime)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
      _detectConflicts();
    });
  }

  Future<void> _submitRegistration() async {
    setState(() => _isSubmitting = true);
    try {
      final subjectIds = _subjects.map((s) => s.id).toList();
      await ApiService().submitRegistration(
        token: widget.controller.token!,
        subjectIds: subjectIds,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDropConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subject'),
        content: Text('Remove ${_subjects[index].name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeSubject(index);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCredits =
        _subjects.fold<int>(0, (sum, s) => sum + (s.creditHours ?? 0));
    final maxCredits = 18;
    final creditProgress = ((totalCredits / maxCredits).clamp(0, 1) * 100).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Registration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selected Subjects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('READY', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${_subjects.length} subject(s) selected', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Credits Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Credits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('$totalCredits / $maxCredits', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: creditProgress / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        creditProgress <= 100 ? Colors.blue : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Conflict Warning
            if (_conflictMap.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_conflictMap.length ~/ 2} schedule conflict(s) detected',
                        style: TextStyle(color: Colors.red[700], fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Subjects List
            const Text('Registered Subjects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._subjects.asMap().entries.map((entry) {
              final index = entry.key;
              final subject = entry.value;
              final hasConflict = _conflictMap.containsKey(index);
              final conflictWith = _conflictMap[index];

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: hasConflict ? Colors.red[200]! : Colors.grey[200]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        subject.code ?? '',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${subject.creditHours ?? 0} Credits',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subject.name ?? '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showDropConfirmation(index),
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Lecture Section
                        if (subject.lectureSection != null && subject.lectureSection!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(color: Colors.blue[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Lecture',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Section ${subject.lectureSection}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subject.lecturer ?? '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      subject.lectureSchedule ?? '',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (subject.labSection != null && subject.labSection!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                border: Border.all(color: Colors.purple[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Lab',
                                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Lab ${subject.labSection}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subject.labInstructor ?? '',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 12, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        subject.labSchedule ?? '',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Conflict Badge
                        if (hasConflict)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                border: Border.all(color: Colors.red[200]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, size: 14, color: Colors.red[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Clashes with: $conflictWith',
                                    style: TextStyle(fontSize: 11, color: Colors.red[600], fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }).toList(),

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : (_subjects.isEmpty ? null : _submitRegistration),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Confirm Registration',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
            ),
          ],
        ),
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
