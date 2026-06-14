import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';
import '../../models/app_user.dart';
import 'EditProfilePage.dart';
import 'ModuleBookingPage.dart';
import 'CurriculumActivityPage.dart';
import 'StudentNotificationsPage.dart';

/// Top-level home page shown to authenticated students.
///
/// Acts as a mini-router for the student-facing portion of the app: it owns
/// the bottom [NavigationBar] (Home / Notification / Attend / Profile) and
/// swaps the body between the home dashboard, notifications, profile view,
/// the Curriculum Activity module ([StudentCurriculumContent]), and the
/// KoQ module booking flow ([KoQBookingContent]) — all without using
/// [Navigator] routes, so state (like [_notifUnreadCount]) is preserved.
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  /// Index of the selected bottom navigation tab:
  /// 0 = Home, 1 = Notification, 2 = Attend (placeholder), 3 = Profile.
  int _selectedIndex = 0;

  /// True when the Curriculum Activity module is open over the Home tab.
  bool _showCurriculum = false;

  /// True when the KoQ module booking flow is open (reached from Curriculum).
  bool _showKoQ = false;

  /// Activity IDs the student is already registered for, passed to the KoQ
  /// booking page so it can hide/disable activities already taken.
  Set<int> _koqRegisteredIds = {};

  /// Number of unread notifications, shown as a badge on the Notification tab.
  int _notifUnreadCount = 0;

  // Set when the student taps a notification, so the Curriculum Activity
  // page can scroll to and highlight the related registration on load.
  int? _highlightRegistrationId;

  // Persists across rebuilds so the badge reflects reality even after leaving tab 1.
  static DateTime? _sLastNotifViewed;

  @override
  void initState() {
    super.initState();
    // Fetch the unread notification count as soon as the home page loads,
    // so the badge on the Notification tab is accurate immediately.
    _loadNotifCount();
  }

  /// Computes how many of the student's registrations have a status update
  /// (claimed/pending/rejected) that the student hasn't seen yet, and
  /// stores the result in [_notifUnreadCount] for the bottom nav badge.
  ///
  /// A registration counts as "unread" if its [ActivityRegistration.updatedAt]
  /// is after [_sLastNotifViewed] (or if the tab has never been viewed).
  /// 'not_claimed' registrations are excluded since they have no status
  /// update to notify about. Errors are swallowed so a failed fetch simply
  /// leaves the badge at its previous value.
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

  /// Opens the Curriculum Activity module, but first checks with the backend
  /// whether Pusat Adab currently has student access open for this module.
  ///
  /// If access is closed, shows [_AccessClosedDialog] instead of navigating.
  /// If the access check itself fails (e.g. network error), the check is
  /// skipped and the module opens as usual rather than blocking the student.
  Future<void> _openCurriculum() async {
    try {
      final isOpen = await widget.controller.apiService.getStudentAccessOpen(
        token: widget.controller.token!,
      );
      if (!isOpen) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => const _AccessClosedDialog(),
        );
        return;
      }
    } catch (_) {
      // If the check itself fails, fall through and let the module load as usual.
    }
    if (!mounted) return;
    setState(() {
      _showCurriculum = true;
      _highlightRegistrationId = null;
    });
  }

  /// Navigates to the Curriculum Activity page and scrolls to/highlights the
  /// registration that the tapped notification refers to.
  void _openActivityFromNotification(ActivityRegistration reg) {
    setState(() {
      _selectedIndex = 0;
      _showCurriculum = true;
      _showKoQ = false;
      _highlightRegistrationId = reg.id;
    });
  }

  /// Opens the KoQ module booking flow, passing along the activity IDs the
  /// student is already registered for (so they can be filtered out there).
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

  /// Builds the scaffold: a [PopScope] that intercepts the system back
  /// button to close the Curriculum/KoQ overlays instead of leaving the
  /// page, a bottom [NavigationBar] for tab switching, a persistent header,
  /// and a body that switches between the various sub-pages/content widgets.
  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;

    return PopScope(
      // Block the default "pop" (which would exit the home page) while the
      // Curriculum or KoQ overlay is open, so back navigates within the
      // module instead of leaving the app's root page.
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
        // ── Bottom navigation bar ──────────────────────────────────────────
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
              _highlightRegistrationId = null;
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
                            onOpenActivity: _openActivityFromNotification,
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
                                    highlightRegistrationId: _highlightRegistrationId,
                                  )
                                : _buildHomeView(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the default "Home" tab content: a welcome card and a grid of
  /// quick action shortcuts. Only "Curriculum Activity" is wired up
  /// ([_openCurriculum]); the others show a "coming soon" snackbar via
  /// [_showSoon].
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
                onTap: _openCurriculum,
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

  /// Builds the "Profile" tab content: a gradient header card with an edit
  /// shortcut to [EditProfilePage], a card of read-only personal info, and
  /// a logout button.
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

  /// Signs the student out via [AppController.signOut]. The controller
  /// clears [AppController.currentUser]/token and notifies listeners, which
  /// causes [SamsApp] to rebuild and show [LoginPage] again.
  Future<void> _logout() async {
    await widget.controller.signOut();
  }

  /// Shows a placeholder snackbar for features that aren't implemented yet.
  void _showSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// Single row in the "Personal Information" card: an icon, a label, and a
/// value, with an optional bottom divider.
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

/// Small rounded square showing the UMPSA logo, used in the persistent
/// header at the top of the home page.
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

/// Gradient card at the top of the Home tab showing the student's name,
/// student ID, and current semester.
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

/// Dialog shown by [_StudentHomePageState._openCurriculum] when Pusat Adab
/// has closed student access to the Curriculum Activity module.
class _AccessClosedDialog extends StatelessWidget {
  const _AccessClosedDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE5E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: Color(0xFFFF3B30), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Closed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Curriculum Activity is currently closed by Pusat Adab. '
              'Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E6BFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable card used in the "Quick Actions" grid on the Home tab.
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
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
