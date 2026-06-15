import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../models/subject.dart';
import 'SubjectSectionSelectionPage.dart';

class AvailableSubjectsPage extends StatefulWidget {
  final AppController controller;
  final Set<int> selectedSubjectIds;
  final List<Subject> selectedSubjects;
  final List<Subject> registeredSubjects;

  const AvailableSubjectsPage({
    super.key,
    required this.controller,
    required this.selectedSubjectIds,
    required this.selectedSubjects,
    required this.registeredSubjects,
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
    if (token == null) throw Exception('Authentication token is missing.');
    
    final data = await widget.controller.apiService.getSubjects(token: token);
    return data.map<Subject>((json) => Subject.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Subject', style: TextStyle(color: Color(0xFF1E3A8A))),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final subjects = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              
              // Logic to check status
              final isPending = widget.selectedSubjectIds.contains(subject.id);
              final isRegistered = widget.registeredSubjects.any((s) => s.id == subject.id);
              final alreadySelected = isPending || isRegistered;
              
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
                            child: Text(
                              '${subject.code} · ${subject.name}', 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadySelected ? Colors.grey[300] : const Color(0xFF2563EB),
                              foregroundColor: alreadySelected ? Colors.black : Colors.white,
                              elevation: 0,
                            ),
                            onPressed: alreadySelected ? null : () async {
                              final updatedSubject = await Navigator.of(context).push<Subject>(
                                MaterialPageRoute(
                                  builder: (_) => SubjectSectionSelectionPage(
                                    subject: subject,
                                    existingSubjects: widget.selectedSubjects,
                                    controller: widget.controller,
                                  ),
                                ),
                              );

                              if (updatedSubject != null && context.mounted) {
                                Navigator.of(context).pop(updatedSubject);
                              }
                            },
                            // Dynamic text based on registration status
                            child: Text(isRegistered ? 'Registered' : (isPending ? 'Selected' : 'Select')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${subject.creditHours} credit hours', 
                        style: const TextStyle(color: Color(0xFF64748B))
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