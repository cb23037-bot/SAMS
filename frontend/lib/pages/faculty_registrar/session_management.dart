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
    widget.controller.apiService.setController(widget.controller);
    _refreshSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = widget.controller.apiService.getAcademicSessions();
    });
  }

  Future<void> _updateRegistrationStatus(int sessionId, bool newValue) async {
    try {
      await widget.controller.apiService.setRegistrationStatus(sessionId, newValue);
      _refreshSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: ${e.toString()}')),
      );
    }
  }

  // Dialog with separate year field + semester dropdown
  void _showAddSessionDialog() {
    final yearController = TextEditingController();
    int selectedSemester = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Academic Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  hintText: 'e.g., 2026/2027',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedSemester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: [1, 2, 3]
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('Semester $s'),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSemester = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final year = yearController.text.trim();
                if (year.isEmpty) return;
                final name = '$year Semester $selectedSemester';
                try {
                  await widget.controller.apiService.createSession(name);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _refreshSessions();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to create: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSession(int sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.controller.apiService.deleteSession(sessionId);
        _refreshSessions();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.AppColors.background,
      appBar: AppBar(
          title: const Text('Manage Sessions', style: theme.AppText.heading)),
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
          if (sessions.isEmpty) {
            return const Center(child: Text('No academic sessions found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final dynamic item = sessions[index];
              final Map<String, dynamic> session =
                  (item is Map) ? Map<String, dynamic>.from(item) : {};
              if (session.isEmpty) return const SizedBox.shrink();

              final bool isActive =
                  session['is_active'] == true || session['is_active'] == 1;
              final bool isOpen = session['is_registration_open'] == true ||
                  session['is_registration_open'] == 1;
              final int sessionId = session['id'] as int;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Session name + active badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session['session_name']?.toString() ?? 'Unnamed',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Registration status badge
                      Row(
                        children: [
                          Icon(
                            isOpen ? Icons.lock_open : Icons.lock,
                            size: 14,
                            color: isOpen ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOpen
                                ? 'Registration Open'
                                : 'Registration Closed',
                            style: TextStyle(
                                fontSize: 13,
                                color: isOpen ? Colors.blue : Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Open / Close Access button + Delete icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isOpen ? Colors.red.shade400 : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                                isOpen ? Icons.lock : Icons.lock_open,
                                size: 16),
                            label: Text(
                                isOpen ? 'Close Access' : 'Open Access'),
                            onPressed: () =>
                                _updateRegistrationStatus(sessionId, !isOpen),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _deleteSession(sessionId),
                          ),
                        ],
                      ),
                    ],
                  ),
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
