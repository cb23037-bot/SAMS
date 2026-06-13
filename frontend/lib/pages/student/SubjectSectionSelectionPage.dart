import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/subject.dart';

class SubjectSectionSelectionPage extends StatefulWidget {
  final Subject subject;
  final List<Subject> existingSubjects;
  final AppController controller;

  const SubjectSectionSelectionPage({
    super.key,
    required this.subject,
    required this.existingSubjects,
    required this.controller,
  });

  @override
  State<SubjectSectionSelectionPage> createState() => _SubjectSectionSelectionPageState();
}

class _SubjectSectionSelectionPageState extends State<SubjectSectionSelectionPage> {
  late List<SectionOption> _lectureOptions;
  late List<SectionOption> _labOptions;
  SectionOption? _selectedLecture;
  SectionOption? _selectedLab;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _lectureOptions = widget.subject.lectureSections.isNotEmpty
        ? widget.subject.lectureSections
        : [SectionOption(
            section: widget.subject.lectureSection ?? '01',
            instructor: widget.subject.lecturer,
            schedule: widget.subject.lectureSchedule,
          )];
    _labOptions = widget.subject.labSections.isNotEmpty
        ? widget.subject.labSections
        : (widget.subject.labSection != null || widget.subject.labInstructor != null || widget.subject.labSchedule != null
            ? [SectionOption(
                section: widget.subject.labSection ?? '01A',
                instructor: widget.subject.labInstructor,
                schedule: widget.subject.labSchedule,
              )]
            : []);
    if (_lectureOptions.isNotEmpty) _selectedLecture = _lectureOptions.first;
    if (_labOptions.isNotEmpty) _selectedLab = _labOptions.first;
  }

  bool _clashesWithExisting(String? schedule) {
    if (schedule == null || schedule.isEmpty) return false;
    final scheduleItem = _parseSchedule(schedule);
    if (scheduleItem == null) return false;

    for (final existing in widget.existingSubjects) {
      if (_subjectHasScheduleConflict(existing, scheduleItem)) {
        return true;
      }
    }
    return false;
  }

  bool _subjectHasScheduleConflict(Subject subject, _Schedule scheduleItem) {
    final schedules = <_Schedule>[];
    if (subject.lectureSchedule != null) {
      final parsed = _parseSchedule(subject.lectureSchedule!);
      if (parsed != null) schedules.add(parsed);
    }
    if (subject.labSchedule != null) {
      final parsed = _parseSchedule(subject.labSchedule!);
      if (parsed != null) schedules.add(parsed);
    }

    for (final existing in schedules) {
      if (existing.day == scheduleItem.day && existing.startTime < scheduleItem.endTime && existing.endTime > scheduleItem.startTime) {
        return true;
      }
    }
    return false;
  }

  _Schedule? _parseSchedule(String schedule) {
    final parts = schedule.split(' ');
    if (parts.length < 2) return null;
    final day = parts[0];
    final range = parts.sublist(1).join(' ');
    final times = range.split('-');
    if (times.length != 2) return null;
    final start = _parseTime(times[0].trim());
    final end = _parseTime(times[1].trim());
    if (start == null || end == null) return null;
    return _Schedule(day: day, startTime: start, endTime: end);
  }

  int? _parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  bool get _canConfirm {
    if (_selectedLecture == null) return false;
    if (_clashesWithExisting(_selectedLecture?.schedule)) return false;
    if (_labOptions.isNotEmpty) {
      if (_selectedLab == null) return false;
      if (_clashesWithExisting(_selectedLab?.schedule)) return false;
    }
    return true;
  }

  void _confirmSelection() async {
    if (!_canConfirm) return;

    setState(() => _isSubmitting = true);

    try {
      final token = widget.controller.token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please log in again.')),
        );
        return;
      }

      await widget.controller.apiService.registerStudentSubject(
        token: token,
        subjectId: widget.subject.id,
        lectureSection: _selectedLecture!.section,
        lectureInstructor: _selectedLecture!.instructor,
        lectureSchedule: _selectedLecture!.schedule,
        labSection: _selectedLab?.section,
        labInstructor: _selectedLab?.instructor,
        labSchedule: _selectedLab?.schedule,
      );

      if (!mounted) return;

      final chosen = Subject(
        id: widget.subject.id,
        name: widget.subject.name,
        code: widget.subject.code,
        creditHours: widget.subject.creditHours,
        lectureSection: _selectedLecture?.section,
        lecturer: _selectedLecture?.instructor,
        lectureSchedule: _selectedLecture?.schedule,
        labSection: _selectedLab?.section,
        labInstructor: _selectedLab?.instructor,
        labSchedule: _selectedLab?.schedule,
        lectureSections: widget.subject.lectureSections,
        labSections: widget.subject.labSections,
      );

      Navigator.of(context).pop(chosen);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Sections for ${widget.subject.code}'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lecture Sections', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ..._lectureOptions.map((option) {
              final clash = _clashesWithExisting(option.schedule);
              return RadioListTile<SectionOption>(
                value: option,
                groupValue: _selectedLecture,
                onChanged: clash
                    ? null
                    : (value) => setState(() => _selectedLecture = value),
                title: Text('Section ${option.section}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (option.instructor != null) Text(option.instructor!),
                    if (option.schedule != null) Text(option.schedule!, style: const TextStyle(color: Color(0xFF64748B))),
                    if (clash)
                      const Text('This section clashes with other registered subjects.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            if (_labOptions.isNotEmpty) ...[
              Text('Lab Sections', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              ..._labOptions.map((option) {
                final clash = _clashesWithExisting(option.schedule);
                return RadioListTile<SectionOption>(
                  value: option,
                  groupValue: _selectedLab,
                  onChanged: clash
                      ? null
                      : (value) => setState(() => _selectedLab = value),
                  title: Text('Lab ${option.section}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (option.instructor != null) Text(option.instructor!),
                      if (option.schedule != null) Text(option.schedule!, style: const TextStyle(color: Color(0xFF64748B))),
                      if (clash)
                        const Text('This section clashes with other registered subjects.', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
            ElevatedButton(
              onPressed: (_canConfirm && !_isSubmitting) ? _confirmSelection : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.w700)),
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
