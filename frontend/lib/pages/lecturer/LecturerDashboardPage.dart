import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
// Import your new approval list page here
import 'SubjectApprovalListPage.dart'; 

class LecturerDashboardPage extends StatefulWidget {
  const LecturerDashboardPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<LecturerDashboardPage> createState() => _LecturerDashboardPageState();
}

class _LecturerDashboardPageState extends State<LecturerDashboardPage> {
  Future<void> _logout() async {
    await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const _MiniBrandMark(),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lecturer Portal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        Text('Academic System', style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _logout, 
                    icon: const Icon(Icons.logout, color: Color(0xFFFF3B30))
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Welcome Card
              _WelcomeCard(user: user, role: 'Lecturer'),
              
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              
              // Navigation to Approval Workflow
              _ActionCard(
                title: 'Registration Approvals',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => SubjectApprovalListPage(controller: widget.controller))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Shared Theme Widgets ---

class _MiniBrandMark extends StatelessWidget {
  const _MiniBrandMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: const Color(0xFFF1F6FF), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(6),
        child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user, required this.role});
  final dynamic user;
  final String role;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome Back,', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            Text(role, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDF6)),
            boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white)),
              const SizedBox(width: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ],
          ),
        ),
      );
}