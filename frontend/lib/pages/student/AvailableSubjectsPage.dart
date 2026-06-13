import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/subject.dart';
import 'SubjectSectionSelectionPage.dart';

class AvailableSubjectsPage extends StatefulWidget {
  final AppController controller;
  final Set<int> selectedSubjectIds;
  final List<Subject> selectedSubjects;

  const AvailableSubjectsPage({
    super.key,
    required this.controller,
    required this.selectedSubjectIds,
    required this.selectedSubjects,
  });

  @override
  State<AvailableSubjectsPage> createState() => _AvailableSubjectsPageState();
}

class _AvailableSubjectsPageState extends State<AvailableSubjectsPage> {
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _loadSubjects();
  }

  Future<List<Subject>> _loadSubjects() async {
    final token = widget.controller.token;
    if (token == null) {
      throw Exception('Authentication token is missing.');
    }
    final data = await widget.controller.apiService.getSubjects(token: token);
    return data.map<Subject>((json) => Subject.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Subject'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<List<Subject>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load subjects.', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => setState(() => _subjectsFuture = _loadSubjects()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final subjects = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final alreadySelected = widget.selectedSubjectIds.contains(subject.id);
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${subject.code} · ${subject.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text('${subject.creditHours} credit hours', style: const TextStyle(color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: alreadySelected
                                ? null
                                : () async {
                                    final selected = await Navigator.of(context).push<Subject>(
                                      MaterialPageRoute(
                                        builder: (_) => SubjectSectionSelectionPage(
                                          subject: subject,
                                          existingSubjects: widget.selectedSubjects,
                                          controller: widget.controller,
                                        ),
                                      ),
                                    );
                                    if (selected != null) {
                                      Navigator.of(context).pop(selected);
                                    }
                                  },
                            child: Text(alreadySelected ? 'Selected' : 'Select Subject'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (subject.lectureSections.isNotEmpty)
                        _SectionSummaryCard(
                          label: 'Lecture',
                          section: subject.lectureSections.first.section,
                          instructor: subject.lectureSections.first.instructor,
                          schedule: subject.lectureSections.first.schedule,
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          badgeColor: const Color(0xFF2563EB),
                        )
                      else if (subject.lectureSchedule != null)
                        _SectionSummaryCard(
                          label: 'Lecture',
                          section: subject.lectureSection,
                          instructor: subject.lecturer,
                          schedule: subject.lectureSchedule,
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          badgeColor: const Color(0xFF2563EB),
                        ),
                      if (subject.labSections.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SectionSummaryCard(
                            label: 'Lab',
                            section: subject.labSections.first.section,
                            instructor: subject.labSections.first.instructor,
                            schedule: subject.labSections.first.schedule,
                            backgroundColor: const Color(0xFFF5F3FF),
                            borderColor: const Color(0xFFE9D5FF),
                            badgeColor: const Color(0xFF7C3AED),
                          ),
                        )
                      else if (subject.labSchedule != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SectionSummaryCard(
                            label: 'Lab',
                            section: subject.labSection,
                            instructor: subject.labInstructor,
                            schedule: subject.labSchedule,
                            backgroundColor: const Color(0xFFF5F3FF),
                            borderColor: const Color(0xFFE9D5FF),
                            badgeColor: const Color(0xFF7C3AED),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionSummaryCard extends StatelessWidget {
  final String label;
  final String? section;
  final String? instructor;
  final String? schedule;
  final Color backgroundColor;
  final Color borderColor;
  final Color badgeColor;

  const _SectionSummaryCard({
    required this.label,
    required this.section,
    required this.instructor,
    required this.schedule,
    required this.backgroundColor,
    required this.borderColor,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (section != null) ...[
                const SizedBox(width: 8),
                Text('Section $section', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
              ],
            ],
          ),
          if (instructor != null) ...[
            const SizedBox(height: 6),
            Text(instructor!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
          if (schedule != null) ...[
            const SizedBox(height: 4),
            Text(schedule!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }
}
