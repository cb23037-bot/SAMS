import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/subject.dart';
import 'AvailableSubjectsPage.dart';
import 'TimetablePage.dart';

class SubjectRegistrationPage extends StatefulWidget {
  const SubjectRegistrationPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<SubjectRegistrationPage> createState() => _SubjectRegistrationPageState();
}

class _SubjectRegistrationPageState extends State<SubjectRegistrationPage> {
  late Future<List<Subject>> _subjectsFuture;
  final Set<int> _selectedSubjectIds = {};
  final List<Subject> _selectedSubjects = [];
  bool _isSubmitting = false;

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

  Future<void> _submitRegistration() async {
    if (_selectedSubjects.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = widget.controller.token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication error. Please log in again.')),
        );
        return;
      }

      await widget.controller.apiService.submitSubjectRegistration(token: token);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration submitted successfully!')),
      );

      setState(() {
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        title: const Text('Open Registration', style: TextStyle(color: Color(0xFF1E3A8A))),
      ),
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
          final selectedSubjects = _selectedSubjects;
          final totalCredits = selectedSubjects.fold<int>(0, (sum, subject) => sum + subject.creditHours);
          const maxCredits = 18;
          final progress = (totalCredits / maxCredits).clamp(0, 1).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Open Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                            SizedBox(height: 8),
                            Text('Semester 2 2025/2026', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('OPEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.name ?? 'Student', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text(user?.course ?? 'N/A', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$totalCredits / $maxCredits', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                              const SizedBox(height: 2),
                              const Text('Credits', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress, color: const Color(0xFF2563EB), backgroundColor: const Color(0xFFE2E8F0), minHeight: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final selected = await Navigator.of(context).push<Subject>(
                              MaterialPageRoute(
                                builder: (_) => AvailableSubjectsPage(
                                  controller: widget.controller,
                                  selectedSubjectIds: _selectedSubjectIds,
                                  selectedSubjects: _selectedSubjects,
                                ),
                              ),
                            );
                            if (selected != null && !_selectedSubjectIds.contains(selected.id)) {
                              setState(() {
                                _selectedSubjectIds.add(selected.id);
                                _selectedSubjects.add(selected);
                              });
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Subject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectedSubjects.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TimetablePage(
                                        selectedSubjects: _selectedSubjects,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.calendar_month_outlined, size: 18),
                          label: const Text('Timetable'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Selected Subjects for Registration',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedSubjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No subjects have been selected for registration yet.', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final selected = await Navigator.of(context).push<Subject>(
                              MaterialPageRoute(
                                builder: (_) => AvailableSubjectsPage(
                                  controller: widget.controller,
                                  selectedSubjectIds: _selectedSubjectIds,
                                  selectedSubjects: _selectedSubjects,
                                ),
                              ),
                            );
                            if (selected != null && !_selectedSubjectIds.contains(selected.id)) {
                              setState(() {
                                _selectedSubjectIds.add(selected.id);
                                _selectedSubjects.add(selected);
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                          child: const Text('Select Subjects', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedSubjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final subject = selectedSubjects[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                  IconButton(
                                    onPressed: () async {
                                      try {
                                        final token = widget.controller.token;
                                        if (token != null) {
                                          await widget.controller.apiService.unregisterStudentSubject(
                                            token: token,
                                            subjectId: subject.id,
                                          );
                                        }
                                        setState(() {
                                          _selectedSubjectIds.remove(subject.id);
                                          _selectedSubjects.removeWhere((item) => item.id == subject.id);
                                        });
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error removing subject: ${e.toString()}')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (subject.lecturer != null || subject.lectureSection != null || subject.lectureSchedule != null)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Lecture', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                                      const SizedBox(height: 6),
                                      if (subject.lectureSection != null) Text('Section ${subject.lectureSection}', style: const TextStyle(color: Color(0xFF0F172A))),
                                      if (subject.lecturer != null) Text(subject.lecturer!, style: const TextStyle(color: Color(0xFF475569))),
                                      if (subject.lectureSchedule != null) Text(subject.lectureSchedule!, style: const TextStyle(color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              if (subject.labSection != null || subject.labInstructor != null || subject.labSchedule != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Lab', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5B21B6))),
                                        const SizedBox(height: 6),
                                        if (subject.labSection != null) Text('Lab ${subject.labSection}', style: const TextStyle(color: Color(0xFF0F172A))),
                                        if (subject.labInstructor != null) Text(subject.labInstructor!, style: const TextStyle(color: Color(0xFF475569))),
                                        if (subject.labSchedule != null) Text(subject.labSchedule!, style: const TextStyle(color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: _selectedSubjectIds.isEmpty || _isSubmitting ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Registration', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
