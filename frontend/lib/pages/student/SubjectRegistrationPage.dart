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
  late Future<void> _initFuture;
  final Set<int> _selectedSubjectIds = {};
  final List<Subject> _selectedSubjects = [];
  List<Subject> _registeredSubjects = []; // NEW: List for confirmed subjects
  bool _isSubmitting = false;

  bool _isRegistrationOpen = false;
  Map<String, dynamic>? _sessionData;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializePage();
  }

  Future<void> _initializePage() async {
    final token = widget.controller.token;
    if (token == null) throw Exception('Authentication token is missing.');

    final session = await widget.controller.apiService.getActiveSession(token: token);
    final data = await widget.controller.apiService.getSubjects(token: token);
    
    // Fetch existing registrations
    List<dynamic> registrations = [];
    try {
      final regData = await widget.controller.apiService.getStudentSubjectRegistrations(token: token);
      // Adjust based on your API response structure
      registrations = (regData is Map) 
    ? ((regData as Map<String, dynamic>)['registrations'] ?? []) 
    : (regData as List);
    } catch (e) {
      debugPrint("DEBUG: Could not load registrations: $e");
    }

    if (mounted) {
      setState(() {
        _sessionData = session;
        _isRegistrationOpen = session != null;
        _registeredSubjects = registrations.map<Subject>((reg) => Subject.fromJson(reg['subject'])).toList();
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (_selectedSubjects.isEmpty) return;
    setState(() => _isSubmitting = true);

    try {
      final token = widget.controller.token;
      if (token == null) return;
      await widget.controller.apiService.submitSubjectRegistration(token: token);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration submitted successfully!')));
      
      // Reset and refresh
      _selectedSubjects.clear();
      _selectedSubjectIds.clear();
      _initializePage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A8A)),
        title: Text(_isRegistrationOpen ? 'Open Registration' : 'Registration Closed', 
                    style: const TextStyle(color: Color(0xFF1E3A8A))),
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return _isRegistrationOpen ? _buildRegistrationForm() : _buildClosedView();
        },
      ),
    );
  }

  Widget _buildClosedView() {
    return const Center(
      child: Text('Registration is currently closed.', style: TextStyle(fontSize: 16, color: Color(0xFF64748B))),
    );
  }

  Widget _buildRegistrationForm() {
    final user = widget.controller.currentUser;
    final totalCredits = _selectedSubjects.fold<int>(0, (sum, subject) => sum + subject.creditHours);
    const maxCredits = 18;
    final progress = (totalCredits / maxCredits).clamp(0, 1).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))]),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Open Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))), const SizedBox(height: 8), Text(_sessionData?['session_name'] ?? 'Semester 2 2025/2026', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(999)), child: const Text('OPEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          
          // Registered Subjects Section (NEW)
          if (_registeredSubjects.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('My Registered Subjects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)))),
            ..._registeredSubjects.map((s) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.blue.shade50,
              elevation: 0,
              child: ListTile(title: Text(s.name), subtitle: Text(s.code), leading: const Icon(Icons.check_circle, color: Colors.blue)),
            )),
            const SizedBox(height: 16),
          ],

          // Registration Progress
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?.name ?? 'Student', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))), const SizedBox(height: 4), Text(user?.course ?? 'N/A', style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)))]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$totalCredits / $maxCredits', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))), const Text('Credits', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))])
                ]),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress, color: const Color(0xFF2563EB), backgroundColor: const Color(0xFFE2E8F0), minHeight: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () async {
                  final selected = await Navigator.of(context).push<Subject>(MaterialPageRoute(builder: (_) => AvailableSubjectsPage(controller: widget.controller, selectedSubjectIds: _selectedSubjectIds, selectedSubjects: _selectedSubjects, registeredSubjects: _registeredSubjects,)));
                  if (selected != null && !_selectedSubjectIds.contains(selected.id)) { setState(() { _selectedSubjectIds.add(selected.id); _selectedSubjects.add(selected); }); }
                }, icon: const Icon(Icons.add, size: 18), label: const Text('Add Subject'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), padding: const EdgeInsets.symmetric(vertical: 14))),),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(onPressed: _selectedSubjects.isEmpty ? null : () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimetablePage(selectedSubjects: _selectedSubjects))); }, icon: const Icon(Icons.calendar_month_outlined, size: 18), label: const Text('Timetable'), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(vertical: 14))),),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Selected Subjects for Registration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
          const SizedBox(height: 12),
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedSubjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subject = _selectedSubjects[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${subject.code} · ${subject.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text('${subject.creditHours} credit hours', style: const TextStyle(color: Color(0xFF64748B)))])),
                  IconButton(onPressed: () => setState(() { _selectedSubjectIds.remove(subject.id); _selectedSubjects.removeWhere((item) => item.id == subject.id); }), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                ])),
              );
            },
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _selectedSubjectIds.isEmpty || _isSubmitting ? null : _submitRegistration,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFF2563EB)),
              child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Submit Registration', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}