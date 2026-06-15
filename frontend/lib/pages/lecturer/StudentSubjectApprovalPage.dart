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
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      final dynamic data = await widget.controller.apiService.getStudentPendingSubjects(
        token: widget.controller.token!, 
        studentId: widget.studentId
      );
      
      List<dynamic> parsedList = [];
      if (data is List) {
        parsedList = data;
      } else if (data is Map<String, dynamic>) {
        parsedList = data['subjects'] ?? data['registrations'] ?? [];
      }
      
      setState(() => _subjects = parsedList);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAll() async {
    setState(() => _isProcessing = true);
    try {
      await widget.controller.apiService.approveAllRegistrations(
        token: widget.controller.token!,
        studentId: widget.studentId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All registrations approved.')),
        );
        Navigator.pop(context); // Go back to the student list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Registrations'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? const Center(child: Text('No pending registrations found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final registration = _subjects[index];
                    final subjectData = registration['subject'] ?? {};
                    
                    final String subjectName = subjectData['name']?.toString() ?? 'Unknown Subject';
                    final String subjectCode = subjectData['code']?.toString() ?? 'No Code';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Code: $subjectCode'),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _subjects.isNotEmpty && !_isLoading
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isProcessing ? null : _approveAll,
                child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('APPROVE ALL SUBJECTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          : null,
    );
  }
}