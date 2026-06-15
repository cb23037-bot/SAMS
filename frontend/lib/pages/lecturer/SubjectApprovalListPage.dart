import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import 'StudentSubjectApprovalPage.dart';

class SubjectApprovalListPage extends StatefulWidget {
  const SubjectApprovalListPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SubjectApprovalListPage> createState() => _SubjectApprovalListPageState();
}

class _SubjectApprovalListPageState extends State<SubjectApprovalListPage> {
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPending();
  }

  Future<void> _fetchPending() async {
    setState(() => _isLoading = true);
    try {
      final dynamic data = await widget.controller.apiService.getPendingStudents(
        token: widget.controller.token!
      );

      List<dynamic> parsedList = [];
      if (data is Map<String, dynamic>) {
        parsedList = data['students'] ?? [];
      } else if (data is List) {
        parsedList = data;
      }

      setState(() => _students = parsedList);
    } catch (e) {
      debugPrint("DEBUG: Error fetching students: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(child: Text('No students with pending requests.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final item = _students[index];
                    
                    // --- DEBUG ---
                    // Run with 'flutter run' and check Logcat/Debug Console for:
                    // DEBUG: Row Data: {...}
                    debugPrint("DEBUG: Row Data: $item");

                    final String name = item['student_name']?.toString() ?? 'Unknown Student';
                    
                    // --- KEY FIX ---
                    // Check your debug console for the correct key name
                    final String studentId = item['student_id']?.toString() 
                                          ?? item['student_number']?.toString() 
                                          ?? item['matric_no']?.toString()
                                          ?? item['id']?.toString() 
                                          ?? 'N/A';
                    
                    final dynamic rawId = item['user_id'];
                    final int? sId = (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: sId != null 
                            ? () => Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => StudentSubjectApprovalPage(
                                  controller: widget.controller, 
                                  studentId: sId
                                ))
                              )
                            : null,
                        child: ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: $studentId'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}