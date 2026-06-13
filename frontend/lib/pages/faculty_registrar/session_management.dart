import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../theme/app_theme.dart' as theme;

class ManageSessionPage extends StatefulWidget {
  final AppController controller;
  const ManageSessionPage({super.key, required this.controller});

  @override
  State<ManageSessionPage> createState() => _ManageSessionPageState();
}

class _ManageSessionPageState extends State<ManageSessionPage> {
  late Future<List<dynamic>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = widget.controller.apiService.getAcademicSessions();
    });
  }

  // --- Add Session Dialog ---
  void _showAddSessionDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Academic Session'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "e.g., 2026/2027"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await widget.controller.apiService.createSession(nameController.text);
                if (mounted) Navigator.pop(ctx);
                _refreshSessions();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // --- Delete Session Logic ---
  Future<void> _deleteSession(int sessionId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.controller.apiService.deleteSession(sessionId);
        _refreshSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }

  // --- Toggle Registration Logic ---
  Future<void> _toggleRegistration(int sessionId, bool newValue) async {
    try {
      await widget.controller.apiService.updateRegistrationStatus(sessionId, newValue);
      _refreshSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.AppColors.background,
      appBar: AppBar(title: const Text('Manage Sessions', style: theme.AppText.heading)),
      body: FutureBuilder<List<dynamic>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final sessions = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(session['session_name'] ?? 'Unnamed'),
                      subtitle: Text((session['is_active'] == true) ? "Active Session" : ""),
                      value: session['is_registration_open'] == true,
                      onChanged: (bool value) => _toggleRegistration(session['id'], value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteSession(session['id']),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSessionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}