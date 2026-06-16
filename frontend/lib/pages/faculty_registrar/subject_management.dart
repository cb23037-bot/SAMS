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

  Future<void> _fetchSubjects() async {
    final String? token = widget.controller.token;
    if (token == null) return;

    setState(() => _isLoading = true);
    try {
      final subjects = await _apiService.getSubjects(token: token);
      if (mounted) {
        setState(() {
          _allSubjects = subjects;
          _filteredSubjects = subjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading subjects: $e')));
      }
    }
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
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubjects.isEmpty
                    ? const Center(child: Text("No subjects found."))
                    : ListView.builder(
                        itemCount: _filteredSubjects.length,
                        itemBuilder: (context, index) {
                          final subject = _filteredSubjects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                            child: ListTile(
                              title: Text(subject['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Code: ${subject['code']} | Credits: ${subject['credit_hours']}"),
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
          if (result == true) _fetchSubjects();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}