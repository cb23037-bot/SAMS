import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../theme/app_theme.dart' as theme;
import 'session_management.dart';
import 'subject_management.dart'; // Added import for Subject Management

class FacultyRegistrarDashboard extends StatelessWidget {
  const FacultyRegistrarDashboard({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.AppColors.background,
      appBar: AppBar(
        title: const Text('Registrar Portal', style: theme.AppText.heading),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: theme.AppColors.textMain,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome, Registrar', style: theme.AppText.heading),
            const Text('Manage academic curriculum and subject registrations.', style: theme.AppText.subTitle),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _DashboardCard(
                  title: 'Session Management',
                  icon: Icons.library_books_outlined,
                  color: theme.AppColors.primaryBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageSessionPage(controller: controller),
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Subject Management',
                  icon: Icons.book_outlined,
                  color: theme.AppColors.primaryGreen ?? Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // Assuming your SubjectManagementPage needs the controller
                        builder: (context) => SubjectManagementPage(controller: controller), 
                      ),
                    );
                  },
                ),
                _DashboardCard(
                  title: 'Student Records',
                  icon: Icons.people_outline,
                  color: theme.AppColors.primaryPurple,
                  onTap: () {
                    // Add navigation to student records here if needed
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.signOut();
    }
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title, 
    required this.icon, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0A0D1B2A), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontWeight: FontWeight.w700, color: theme.AppColors.textMain)
            ),
          ],
        ),
      ),
    );
  }
}