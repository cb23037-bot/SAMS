import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';
import '../../models/app_user.dart';
import 'EditProfilePage.dart';
import 'ModuleBookingPage.dart';
import 'CurriculumActivityPage.dart';
import 'StudentNotificationsPage.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _selectedIndex = 0;
  bool _showCurriculum = false;
  bool _showKoQ = false;
  Set<int> _koqRegisteredIds = {};
  int _notifUnreadCount = 0;

  // Persists across rebuilds so the badge reflects reality even after leaving tab 1.
  static DateTime? _sLastNotifViewed;

  @override
  void initState() {
    super.initState();
    _loadNotifCount();
  }

  Future<void> _loadNotifCount() async {
    try {
      final regs = await widget.controller.apiService.getStudentRegistrations(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      final lastViewed = _sLastNotifViewed;
      final count = regs.where((ActivityRegistration r) {
        if (r.claimStatus == 'not_claimed') return false;
        if (lastViewed == null) return true;
        final ts = r.updatedAt;
        if (ts == null) return false;
        return DateTime.tryParse(ts)?.isAfter(lastViewed) ?? false;
      }).length;
      setState(() => _notifUnreadCount = count);
    } catch (_) {}
  }

  void _openKoQ(Set<int> registeredIds) {
    setState(() {
      _showKoQ = true;
      _koqRegisteredIds = registeredIds;
    });
  }

  void _closeKoQ() {
    // Setting _showKoQ = false destroys KoQBookingContent and recreates
    // StudentCurriculumContent, which triggers initState → _load() automatically.
    setState(() => _showKoQ = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;

    return PopScope(
      canPop: !_showCurriculum && !_showKoQ,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_showKoQ) {
            _closeKoQ();
          } else if (_showCurriculum) {
            setState(() => _showCurriculum = false);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0x1A1E5BFF),
          onDestinationSelected: (index) {
            if (index == 1) {
              // Mark all notifications as viewed when the user opens the tab.
              _sLastNotifViewed = DateTime.now();
            }
            setState(() {
              _selectedIndex = index;
              _showCurriculum = false;
              _showKoQ = false;
              if (index == 1) _notifUnreadCount = 0;
            });
            if (index == 2) {
              _showSoon('Attend feature will be connected later.');
            }
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _notifUnreadCount > 0,
                label: Text('$_notifUnreadCount'),
                child: const Icon(Icons.notifications_none_outlined),
              ),
              label: 'Notification',
            ),
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              label: 'Attend',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Persistent top header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    const _MiniBrandMark(),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SA Management',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Academic System',
                            style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: widget.controller.isLoading ? null : _logout,
                      icon: const Icon(Icons.logout, color: Color(0xFFFF3B30)),
                    ),
                  ],
                ),
              ),

              // Body — switches between home / notifications / curriculum / koq / profile
              Expanded(
                child: _selectedIndex == 3
                    ? _buildProfileView(user)
                    : _selectedIndex == 1
                        ? StudentNotificationsContent(
                            controller: widget.controller,
                            lastViewed: _sLastNotifViewed,
                          )
                        : _showKoQ
                            ? KoQBookingContent(
                                controller: widget.controller,
                                registeredActivityIds: _koqRegisteredIds,
                                onBack: _closeKoQ,
                              )
                            : _showCurriculum
                                ? StudentCurriculumContent(
                                    controller: widget.controller,
                                    onBookNow: _openKoQ,
                                  )
                                : _buildHomeView(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeView(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeCard(user: user),
          const SizedBox(height: 18),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 14,
            childAspectRatio: 1.2,
            children: [
              _ActionCard(
                title: 'Register Subjects',
                icon: Icons.menu_book_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () => _showSoon('Register Subjects is coming soon.'),
              ),
              _ActionCard(
                title: 'Mark Attendance',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => _showSoon('Mark Attendance is coming soon.'),
              ),
              _ActionCard(
                title: 'Curriculum Activity',
                icon: Icons.trending_up_outlined,
                color: const Color(0xFFA855F7),
                onTap: () => setState(() => _showCurriculum = true),
              ),
              _ActionCard(
                title: 'Pay Fees',
                icon: Icons.attach_money_outlined,
                color: const Color(0xFFF97316),
                onTap: () => _showSoon('Pay Fees is coming soon.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(AppUser user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // Blue header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0x334A7CFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(user.studentId ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(user.course ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(controller: widget.controller),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.edit_outlined, color: Color(0xFF1E5BFF), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Personal information card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Text(
                    'Personal Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                ),
                const Divider(height: 1),
                _InfoRow(icon: Icons.person_outline, label: 'Name', value: user.name),
                _InfoRow(icon: Icons.badge_outlined, label: 'Student ID', value: user.studentId ?? '-'),
                _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: user.address ?? '-'),
                _InfoRow(icon: Icons.menu_book_outlined, label: 'Academic Advisor', value: user.personalAdvisor ?? '-'),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
                _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phoneNumber ?? '-'),
                _InfoRow(
                  icon: Icons.school_outlined,
                  label: 'Current Semester',
                  value: user.currentSemester ?? '-',
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.controller.isLoading ? null : _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                backgroundColor: const Color(0xFFFFF5F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await widget.controller.signOut();
  }

  void _showSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF5B6B86), size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8))),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 52),
      ],
    );
  }
}

class _MiniBrandMark extends StatelessWidget {
  const _MiniBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
      child: Image.asset('assets/images/umpsa_logo.png', fit: BoxFit.contain),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back,',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${user.studentId ?? '-'}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Current Semester', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                user.currentSemester ?? '-',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EDF6)),
            boxShadow: const [
              BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF111827)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
