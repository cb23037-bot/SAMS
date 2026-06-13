import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../app/app_controller.dart';
import 'AddSubjectPage.dart';

class SubjectManagementPage extends StatefulWidget {
  final AppController controller;

  const SubjectManagementPage({super.key, required this.controller});

  @override
  State<SubjectManagementPage> createState() => _SubjectManagementPageState();
}

class _SubjectManagementPageState extends State<SubjectManagementPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _allSubjects = [];
  List<dynamic> _filteredSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiService.setController(widget.controller);
    _fetchSubjects();
    _searchController.addListener(_filterSubjects);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSubjects() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects = _allSubjects.where((subject) {
        final name = subject['name'].toString().toLowerCase();
        final code = subject['code'].toString().toLowerCase();
        return name.contains(query) || code.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchSubjects() async {
    final String? token = widget.controller.token;
    if (token == null) return;

    try {
      final subjects = await _apiService.getSubjects(token: token);
      setState(() {
        _allSubjects = subjects;
        _filteredSubjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading subjects: $e')));
      }
    }
  }

  Future<void> _deleteSubject(int id) async {
    // Show confirmation dialog before deleting
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: const Text('Are you sure you want to delete this subject?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Assume you implement this in ApiService later
        // await _apiService.deleteSubject(token: widget.controller.token!, id: id);
        _fetchSubjects();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subject Registry")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by code or name...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubjects.isEmpty
                    ? const Center(child: Text("No subjects found."))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          final subject = _filteredSubjects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: ListTile(
                              leading: CircleAvatar(child: Text(subject['code'][0])),
                              title: Text(subject['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Code: ${subject['code']} | Credits: ${subject['credit_hours']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteSubject(subject['id']),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => AddSubjectPage(token: widget.controller.token!))
          );
          if (result == true) _fetchSubjects(); // Refresh only if something was added
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}