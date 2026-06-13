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
      final data = await widget.controller.apiService.getPendingStudents(
        token: widget.controller.token!
      );
      // Ensure we are working with a list
      setState(() => _students = (data is List) ? data : []);
    } catch (e) {
      debugPrint("DEBUG: Error fetching students: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load students: ${e.toString()}')),
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
                    
                    // Defensive null-safe data extraction
                    final String name = item['student_name']?.toString() ?? 'Unknown Student';
                    final String id = item['student_id']?.toString() ?? 'N/A';
                    
                    // We need the ID for navigation. If the backend sends 'id' or 'student_id', 
                    // ensure this points to the database primary key.
                    final dynamic userId = item['user_id']; 
                    final int? sId = (userId is int) ? userId : int.tryParse(userId.toString());
                    debugPrint("DEBUG: Preparing to navigate. Student: $name, UserID: $sId");
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      // InkWell ensures the whole card is clickable
                      child: InkWell(
                        onTap: sId != null 
                            ? () => Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => StudentSubjectApprovalPage(
                                  controller: widget.controller, 
                                  studentId: sId
                                ))
                              )
                            : () => debugPrint("Error: No ID found for this row"),
                        child: ListTile(
                          title: Text(name),
                          subtitle: Text('ID: $id'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}