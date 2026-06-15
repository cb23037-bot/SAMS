import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity.dart';
import '../../models/activity_slot.dart';
import '../../utils/restriction_checker.dart';
import 'fees/manage_fees_dashboard_page.dart';

// Embedded widget — no Scaffold. Used inside StudentHomePage.
/// Lists KoQ (Ko-Kurikulum) activities the student can register for, with
/// search/filtering and a slot-selection dialog for registration.
///
/// Reached from the Curriculum Activity page's "Book Now" action. Activities
/// the student is already registered for ([registeredActivityIds]) and
/// activities with no upcoming (non-past) slots are hidden from the list.
class KoQBookingContent extends StatefulWidget {
  const KoQBookingContent({
    super.key,
    required this.controller,
    required this.registeredActivityIds,
    required this.onBack,
  });

  final AppController controller;

  /// Activity IDs the student has already registered for — excluded from
  /// the bookable list so they can't register twice.
  final Set<int> registeredActivityIds;

  /// Called to return to the Curriculum Activity page (e.g. after the back
  /// button is tapped, or after a successful registration).
  final VoidCallback onBack;

  @override
  State<KoQBookingContent> createState() => _KoQBookingContentState();
}

class _KoQBookingContentState extends State<KoQBookingContent> {
  /// All activities fetched from the backend.
  List<Activity> _activities = [];

  /// [_activities] after applying the registered/past-date/search filters —
  /// this is what's actually rendered in the list.
  List<Activity> _filtered = [];

  /// True while [_load] is fetching activities from the backend.
  bool _loading = true;

  /// Error message from the last failed [_load] call, or null if no error.
  String? _error;

  /// Controls the search box; filtering re-runs via [_filter] on every
  /// keystroke through the listener added in [initState].
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches all activities from the backend and applies [_filter] to
  /// populate [_filtered]. Shows [_ErrorView] on failure with a retry button.
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final activities = await widget.controller.apiService.getActivities(
        token: widget.controller.token!,
      );
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _filter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Recomputes [_filtered] from [_activities] based on:
  /// - excluding activities the student is already registered for,
  /// - excluding activities whose every slot is in the past,
  /// - matching the current search text against the activity name or code.
  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _activities
          .where((a) => !widget.registeredActivityIds.contains(a.id))
          .where((a) => a.slots.any((s) => !_isPastDate(s.date)))
          .where((a) =>
              q.isEmpty ||
              a.name.toLowerCase().contains(q) ||
              a.code.toLowerCase().contains(q))
          .toList();
    });
  }

  /// Opens [_SlotSelectionDialog] for [activity]; if the student picks a
  /// slot and confirms, registers them for that slot via the API.
  ///
  /// On success, shows a green confirmation snackbar and calls
  /// [KoQBookingContent.onBack] to return to the Curriculum Activity page
  /// (which reloads and will show the new registration). On failure, shows
  /// the error in a red snackbar and stays on this page.
  Future<void> _register(Activity activity) async {
    final slotId = await showDialog<int>(
      context: context,
      builder: (_) => _SlotSelectionDialog(activity: activity),
    );
    if (slotId == null || !mounted) return;

    try {
      await widget.controller.apiService.registerSlot(
        token: widget.controller.token!,
        slotId: slotId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: Color(0xFF0EAF4B),
        ),
      );
      widget.onBack(); // return to curriculum (which will reload)
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      // Backend returned 403 → show the restriction dialog
      if (msg.contains('restriction') || msg.contains('restricted') || msg.contains('403')) {
        await checkAndShowRestriction(
          context: context,
          controller: widget.controller,
          onPayNow: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ManageFeesDashboardPage(controller: widget.controller),
          )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  /// Builds the page: a gradient header with a back button, a search bar,
  /// and either a loading spinner, an error view, an "all done" empty
  /// state, or the list of bookable activity cards.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Blue–cyan gradient header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E6BFF), Color(0xFF06B6D4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KoQ Module Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search activities...',
              hintStyle: const TextStyle(color: Color(0xFF8A96A8), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8A96A8)),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 52,
                                    color: Color(0xFFB0BEC5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _activities.isEmpty
                                        ? 'No activities available.'
                                        : 'You are registered for all activities.',
                                    style: const TextStyle(color: Color(0xFF5B6B86)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final activity = _filtered[i];
                                return _ActivityBookingCard(
                                  activity: activity,
                                  onRegister: () => _register(activity),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}

// ── Activity booking card ─────────────────────────────────────────────────────

/// Card showing one activity's name, code, total capacity, and a
/// "Register" button (or "No Slots Available" if [activity.slots] is empty).
class _ActivityBookingCard extends StatelessWidget {
  const _ActivityBookingCard({required this.activity, required this.onRegister});

  final Activity activity;
  final VoidCallback onRegister;

  /// Sum of capacities across all of the activity's slots.
  int get _totalCapacity => activity.slots.fold<int>(0, (s, slot) => s + slot.capacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.tag, label: 'Code: ${activity.code}'),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.group_outlined,
            label: 'Total Capacity: $_totalCapacity participants',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.emoji_events_outlined,
            label: '2 Cats',
            color: const Color(0xFF0EAF4B),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: activity.slots.isEmpty ? null : onRegister,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6BFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                activity.slots.isEmpty ? 'No Slots Available' : 'Register',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon + label row used inside [_ActivityBookingCard] for the
/// activity code, capacity, and CATs reward info.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF5B6B86);
    return Row(
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: c)),
      ],
    );
  }
}

// ── Slot selection dialog ─────────────────────────────────────────────────────

/// Dialog that lets the student pick a date/time slot for [activity].
///
/// Returns the selected slot's ID via `Navigator.pop(slotId)` when
/// "Confirm Registration" is pressed, or null if cancelled/dismissed.
/// [_KoQBookingContentState._register] awaits this result to perform
/// the actual registration API call.
class _SlotSelectionDialog extends StatefulWidget {
  const _SlotSelectionDialog({required this.activity});
  final Activity activity;

  @override
  State<_SlotSelectionDialog> createState() => _SlotSelectionDialogState();
}

class _SlotSelectionDialogState extends State<_SlotSelectionDialog> {
  /// The slot the student has tapped on. The "Confirm Registration" button
  /// is disabled until this is non-null.
  int? _selectedSlotId;

  /// Slots that are both not full and not in the past — the only slots the
  /// student is allowed to pick.
  List<ActivitySlot> get _availableSlots => widget.activity.slots
      .where((s) => s.registered < s.capacity && !_isPastDate(s.date))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Date & Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Color(0xFF5B6B86)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.activity.name,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2E6BFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            if (_availableSlots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No available slots.', style: TextStyle(color: Color(0xFF5B6B86))),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _availableSlots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final slot = _availableSlots[i];
                    final selected = _selectedSlotId == slot.id;
                    final remaining = slot.capacity - slot.registered;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedSlotId = slot.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFEFF4FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? const Color(0xFF2E6BFF) : const Color(0xFFE2E8F0),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(slot.date),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(slot.time, style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
                            const SizedBox(height: 4),
                            Text(
                              'Remaining: $remaining / ${slot.capacity} slots',
                              style: TextStyle(
                                fontSize: 12,
                                color: remaining <= 5 ? const Color(0xFFFF4D4F) : const Color(0xFF0EAF4B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedSlotId == null
                        ? null
                        : () => Navigator.of(context).pop(_selectedSlotId),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6BFF),
                      disabledBackgroundColor: const Color(0xFFCDD9FF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Confirm Registration',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

/// Generic "something went wrong" view with a message and a Retry button,
/// shown when [_KoQBookingContentState._load] fails.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 48, color: Color(0xFFB0BEC5)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5B6B86))),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Date helpers ─────────────────────────────────────────────────────────────

/// Returns true if [dateStr] (format 'YYYY-MM-DD') is strictly before today.
/// Activities/slots happening today are considered "ongoing" and still valid.
bool _isPastDate(String dateStr) {
  final parts = dateStr.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return date.isBefore(today);
}

/// Formats [dateStr] (format 'YYYY-MM-DD') as e.g. "Monday, January 1, 2026"
/// for display in the slot selection dialog.
String _formatDate(String dateStr) {
  final parts = dateStr.split('-');
  final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  const months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${weekdays[dt.weekday]}, ${months[dt.month]} ${dt.day}, ${dt.year}';
}
