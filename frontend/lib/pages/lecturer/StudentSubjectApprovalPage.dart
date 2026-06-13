import 'package:flutter/material.dart';
import '../../app/app_controller.dart';

class StudentSubjectApprovalPage extends StatefulWidget {
  const StudentSubjectApprovalPage({super.key, required this.controller, required this.studentId});
  final AppController controller;
  final int studentId;

  @override
  State<StudentSubjectApprovalPage> createState() => _StudentSubjectApprovalPageState();
}

class _StudentSubjectApprovalPageState extends State<StudentSubjectApprovalPage> {
  List<dynamic> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      // We perform the request. If _request() returns dynamic, we must safely cast.
      final dynamic data = await widget.controller.apiService.getStudentPendingSubjects(
        token: widget.controller.token!, 
        studentId: widget.studentId
      );
      debugPrint("DEBUG: Received subjects count: ${data.length}");

      // DEFENSIVE PARSING: Handle both List and Map responses
      List<dynamic> parsedList = [];
      if (data is List) {
        parsedList = data;
      } else if (data is Map<String, dynamic>) {
        // If wrapped in a key like 'subjects' or 'registrations'
        parsedList = data['subjects'] ?? data['registrations'] ?? [];
      }

      setState(() => _subjects = parsedList);
    } catch (e) {
      debugPrint("DEBUG: API FAILED with error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve(int registrationId) async {
    try {
      await widget.controller.apiService.approveStudentSubjectRegistration(
        token: widget.controller.token!, 
        registrationId: registrationId
      );
      _loadSubjects(); // Refresh list after success
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Subject Approval')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? const Center(child: Text('No pending subjects found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final sub = _subjects[index];
                    
                    // Access safely
                    final String name = sub['subject_name']?.toString() ?? 'Unknown Subject';
                    final String code = sub['subject_code']?.toString() ?? 'No Code';
                    final int? regId = sub['id'] is int ? sub['id'] : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(code),
                        trailing: ElevatedButton(
                          onPressed: regId != null ? () => _approve(regId) : null,
                          child: const Text('Approve'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}