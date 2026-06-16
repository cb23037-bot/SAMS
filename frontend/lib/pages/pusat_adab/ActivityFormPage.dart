import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity.dart';
import 'SlotFormPage.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Main Page
// ═══════════════════════════════════════════════════════════════════════════════

/// Pusat Adab staff page for managing curriculum activities.
///
/// Lists all activities with search/filter, and lets staff add, edit, delete
/// activities, and manage each activity's registration [SlotFormPage]s.
/// All mutations go through [AppController.apiService] and update the local
/// [_all]/[_filtered] lists directly so the UI reflects changes without a
/// full reload.
class CurriculumActivitiesPage extends StatefulWidget {
  const CurriculumActivitiesPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CurriculumActivitiesPage> createState() =>
      _CurriculumActivitiesPageState();
}

class _CurriculumActivitiesPageState extends State<CurriculumActivitiesPage> {
  /// Full, unfiltered list of activities fetched from the API.
  List<Activity> _all = [];

  /// Subset of [_all] currently shown, based on the search query.
  List<Activity> _filtered = [];

  /// True while the initial activity list is being fetched.
  bool _loading = true;

  /// Controls the search bar text used to filter [_all] into [_filtered].
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Fetches all curriculum activities from the API and applies the
  /// current search filter. Shows a snackbar on failure.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.controller.apiService.getActivities(
        token: widget.controller.token!,
      );
      setState(() {
        _all = list;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Recomputes [_filtered] from [_all] based on the search box text.
  /// Matches against activity name, code, or description (case-insensitive).
  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_all)
        : _all
              .where(
                (a) =>
                    a.name.toLowerCase().contains(q) ||
                    a.code.toLowerCase().contains(q) ||
                    (a.description?.toLowerCase().contains(q) ?? false),
              )
              .toList();
  }

  /// Replaces an activity in [_all] with its updated version (after edit
  /// or slot management) and re-applies the search filter.
  void _replaceActivity(Activity updated) {
    setState(() {
      final i = _all.indexWhere((a) => a.id == updated.id);
      if (i != -1) _all[i] = updated;
      _applyFilter();
    });
  }

  /// Removes an activity from [_all] by [id] after a successful delete
  /// and re-applies the search filter.
  void _removeActivity(int id) {
    setState(() {
      _all.removeWhere((a) => a.id == id);
      _applyFilter();
    });
  }

  /// Shows a simple snackbar message (used for error feedback).
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  /// Opens the [_ActivityFormDialog] in "add" mode. If the staff member
  /// saves a new activity, it is prepended to [_all] and the filter is
  /// re-applied.
  Future<void> _showAddDialog() async {
    final created = await showDialog<Activity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActivityFormDialog(controller: widget.controller),
    );
    if (created != null) {
      setState(() {
        _all.insert(0, created);
        _applyFilter();
      });
    }
  }

  /// Opens the [_ActivityFormDialog] in "edit" mode for [activity]. If saved,
  /// the activity in [_all] is replaced with the updated version.
  Future<void> _showEditDialog(Activity activity) async {
    final updated = await showDialog<Activity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActivityFormDialog(
        controller: widget.controller,
        activity: activity,
      ),
    );
    if (updated != null) _replaceActivity(updated);
  }

  /// Shows the [_DeleteActivityDialog] confirmation. Only calls the delete
  /// API and removes the activity locally if the user confirms.
  Future<void> _showDeleteDialog(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteActivityDialog(activity: activity),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.apiService.deleteActivity(
        token: widget.controller.token!,
        id: activity.id,
      );
      _removeActivity(activity.id);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Opens [SlotFormPage] so staff can add/edit/delete registration slots
  /// for [activity]. If slots changed, the returned activity (with refreshed
  /// slot data) replaces the local copy.
  Future<void> _showManageSlotsDialog(Activity activity) async {
    final updated = await showDialog<Activity>(
      context: context,
      builder: (_) =>
          SlotFormPage(activity: activity, controller: widget.controller),
    );
    if (updated != null) _replaceActivity(updated);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header card: back button, title, and "Add Activity" button
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120D1B2A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Curriculum Activities',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              'Add, edit, delete, and manage activities',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5B6B86),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showAddDialog,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Add Activity',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar: filters the list live as the user types
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(_applyFilter),
                decoration: InputDecoration(
                  hintText:
                      'Search activities by name, code, or description...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB0BAC9),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF5B6B86),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                  ),
                ),
              ),
            ),

            // Activity list: shows loading, empty, or the filtered list of
            // activity cards with pull-to-refresh
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No activities found.',
                        style: TextStyle(color: Color(0xFF5B6B86)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ActivityCard(
                          activity: _filtered[i],
                          onEdit: () => _showEditDialog(_filtered[i]),
                          onDelete: () => _showDeleteDialog(_filtered[i]),
                          onManageSlots: () =>
                              _showManageSlotsDialog(_filtered[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Activity Card
// ═══════════════════════════════════════════════════════════════════════════════

/// Displays a single activity's summary (name, code, capacity, available
/// slots, location, description) with action buttons for viewing details,
/// managing slots, editing, and deleting. The actual edit/delete/manage-slots
/// behavior is delegated to the parent page via the provided callbacks.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
    required this.onManageSlots,
  });

  final Activity activity;

  /// Called when the "Edit" button is tapped.
  final VoidCallback onEdit;

  /// Called when the delete (trash) icon is tapped.
  final VoidCallback onDelete;

  /// Called when the "Manage Slots" button is tapped.
  final VoidCallback onManageSlots;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
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
          const SizedBox(height: 4),
          Text(
            activity.code,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E6BFF),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.group_outlined,
                size: 16,
                color: Color(0xFF5B6B86),
              ),
              const SizedBox(width: 6),
              Text(
                'Total Capacity: ${activity.totalCapacity} participants',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: Color(0xFF5B6B86),
              ),
              const SizedBox(width: 6),
              Text(
                '${activity.availableSlotsCount} slot${activity.availableSlotsCount == 1 ? '' : 's'} available',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
              ),
            ],
          ),
          if (activity.location != null && activity.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFF5B6B86),
                ),
                const SizedBox(width: 6),
                Text(
                  activity.location!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5B6B86),
                  ),
                ),
              ],
            ),
          ],
          if (activity.description != null &&
              activity.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activity.description!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A96A8)),
            ),
          ],
          const SizedBox(height: 12),
          // Manage Slots button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManageSlots,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                backgroundColor: const Color(0xFFF5F0FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text(
                'Manage Slots',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // View / Edit / Delete row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showViewDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B6B86),
                    side: const BorderSide(color: Color(0xFFD6E0F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E6BFF),
                    side: const BorderSide(color: Color(0xFF5F9DFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF4D4F),
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens a read-only [AlertDialog] showing the full activity details
  /// (code, location, WhatsApp link, description, capacity, available slots).
  /// Optional fields are only shown if present.
  void _showViewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(activity.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _viewRow('Code', activity.code),
            if (activity.location != null && activity.location!.isNotEmpty)
              _viewRow('Location', activity.location!),
            if (activity.whatsappLink != null)
              _viewRow('WhatsApp', activity.whatsappLink!),
            if (activity.description != null)
              _viewRow('Description', activity.description!),
            _viewRow(
              'Total Capacity',
              '${activity.totalCapacity} participants',
            ),
            _viewRow('Available Slots', '${activity.availableSlotsCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Builds a label/value pair row used inside the view details dialog.
  Widget _viewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Add / Edit Activity Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Dialog form for creating a new activity or editing an existing one.
///
/// When [activity] is null, the dialog operates in "add" mode (activity code
/// is optional and auto-generated by the backend if left blank). When
/// [activity] is provided, the dialog is pre-filled for editing and the code
/// field becomes required. On success, the dialog is popped with the
/// created/updated [Activity] so the caller can update its local list.
class _ActivityFormDialog extends StatefulWidget {
  const _ActivityFormDialog({required this.controller, this.activity});
  final AppController controller;

  /// The activity being edited, or null when adding a new activity.
  final Activity? activity;

  @override
  State<_ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<_ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;

  /// True while the create/update API call is in flight; disables the
  /// form buttons and shows a spinner on the submit button.
  bool _saving = false;

  /// Server-side validation error for the activity code (e.g. duplicate
  /// code), shown as the field's error text.
  String? _codeError;

  /// True when editing an existing activity (i.e. [Activity] was provided).
  bool get _isEdit => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _codeCtrl = TextEditingController(text: a?.code ?? '');
    _waCtrl = TextEditingController(text: a?.whatsappLink ?? '');
    _descCtrl = TextEditingController(text: a?.description ?? '');
    _locationCtrl = TextEditingController(text: a?.location ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _waCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  /// Validates the form, then creates or updates the activity via
  /// [AppController.apiService] depending on [_isEdit].
  ///
  /// On success, pops the dialog with the resulting [Activity]. On failure,
  /// if the error message mentions "code" (duplicate activity code from the
  /// backend), shows it as a field-level error instead of a snackbar so the
  /// user can correct it inline.
  Future<void> _submit() async {
    setState(() => _codeError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final Activity result;
      if (_isEdit) {
        result = await widget.controller.apiService.updateActivity(
          token: widget.controller.token!,
          id: widget.activity!.id,
          name: _nameCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
          whatsappLink: _waCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
        );
      } else {
        result = await widget.controller.apiService.createActivity(
          token: widget.controller.token!,
          name: _nameCtrl.text.trim(),
          code: _codeCtrl.text.trim(),
          whatsappLink: _waCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('code')) {
        setState(() => _codeError = 'This activity code is already in use.');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Activity' : 'Add New Activity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Update the activity details'
                              : 'Enter the details of the new curriculum activity',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5B6B86),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DialogField(
                label: 'Activity Name *',
                controller: _nameCtrl,
                hint: 'Enter activity name',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Activity name is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              // Code is required when editing, but optional when adding —
              // the backend auto-generates a code if left blank for new
              // activities.
              _DialogField(
                label: _isEdit
                    ? 'Activity Code *'
                    : 'Activity Code (optional - auto-generated if empty)',
                controller: _codeCtrl,
                hint: 'e.g., LW202',
                validator: _isEdit
                    ? (v) => v == null || v.trim().isEmpty
                          ? 'Code is required.'
                          : null
                    : null,
                errorText: _codeError,
                onChanged: (_) {
                  if (_codeError != null) setState(() => _codeError = null);
                },
              ),
              const SizedBox(height: 14),
              _DialogField(
                label: 'WhatsApp Link',
                controller: _waCtrl,
                hint: 'https://wa.me/60123456789',
              ),
              const SizedBox(height: 14),
              _DialogField(
                label: 'Description',
                controller: _descCtrl,
                hint: 'Enter activity description',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _DialogField(
                label: 'Location *',
                controller: _locationCtrl,
                hint: 'e.g., Library, UMPSA',
                helperText:
                    'Enter the venue name where the activity will be held',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Location is required.'
                    : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Save Changes' : 'Add Activity',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Delete Confirmation Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Confirmation dialog shown before deleting an activity.
///
/// Returns `true` via [Navigator.pop] if the user confirms deletion, or
/// `false`/`null` if cancelled. The actual delete API call is performed by
/// the caller ([_CurriculumActivitiesPageState._showDeleteDialog]).
class _DeleteActivityDialog extends StatelessWidget {
  const _DeleteActivityDialog({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Delete Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to delete this activity? This action cannot be undone.',
              style: TextStyle(fontSize: 14, color: Color(0xFF5B6B86)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity: ${activity.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Code: ${activity.code}',
                    style: const TextStyle(color: Color(0xFF5B6B86)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared Dialog Field Widget
// ═══════════════════════════════════════════════════════════════════════════════

/// Reusable labeled text field for the activity form dialogs.
///
/// Wraps a [TextFormField] with a consistent label, hint, helper text, and
/// error styling so all fields in [_ActivityFormDialog] look the same.
/// [validator] enables form-level validation; [errorText] is used for
/// server-side errors (e.g. duplicate activity code) that aren't known
/// until [_ActivityFormDialogState._submit] runs.
class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.maxLines = 1,
    this.helperText,
    this.validator,
    this.errorText,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? helperText;

  /// Returns an error message if invalid, or null if the value is valid.
  final String? Function(String?)? validator;

  /// External (server-side) error message to display, separate from
  /// [validator]'s client-side validation.
  final String? errorText;

  /// Called on every keystroke; used to clear [errorText] once the user
  /// starts editing again.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
            helperText: helperText,
            errorText: errorText,
            helperStyle: const TextStyle(
              color: Color(0xFF8A96A8),
              fontSize: 11,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF1E5BFF),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
