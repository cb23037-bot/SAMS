import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity.dart';
import 'SlotFormPage.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Main Page
// ═══════════════════════════════════════════════════════════════════════════════

class CurriculumActivitiesPage extends StatefulWidget {
  const CurriculumActivitiesPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CurriculumActivitiesPage> createState() => _CurriculumActivitiesPageState();
}

class _CurriculumActivitiesPageState extends State<CurriculumActivitiesPage> {
  List<Activity> _all = [];
  List<Activity> _filtered = [];
  bool _loading = true;
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.controller.apiService
          .getActivities(token: widget.controller.token!);
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

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = q.isEmpty
        ? List.from(_all)
        : _all
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.code.toLowerCase().contains(q) ||
                (a.description?.toLowerCase().contains(q) ?? false))
            .toList();
  }

  void _replaceActivity(Activity updated) {
    setState(() {
      final i = _all.indexWhere((a) => a.id == updated.id);
      if (i != -1) _all[i] = updated;
      _applyFilter();
    });
  }

  void _removeActivity(int id) {
    setState(() {
      _all.removeWhere((a) => a.id == id);
      _applyFilter();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final created = await showDialog<Activity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActivityFormDialog(controller: widget.controller),
    );
    if (created != null) {
      setState(() {
        _all.add(created);
        _applyFilter();
      });
    }
  }

  Future<void> _showEditDialog(Activity activity) async {
    final updated = await showDialog<Activity>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActivityFormDialog(controller: widget.controller, activity: activity),
    );
    if (updated != null) _replaceActivity(updated);
  }

  Future<void> _showDeleteDialog(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteActivityDialog(activity: activity),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.apiService
          .deleteActivity(token: widget.controller.token!, id: activity.id);
      _removeActivity(activity.id);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _showManageSlotsDialog(Activity activity) async {
    final updated = await Navigator.of(context).push<Activity>(
      MaterialPageRoute(
        builder: (_) => SlotFormPage(
          activity:   activity,
          controller: widget.controller,
        ),
      ),
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
            // Header card
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x120D1B2A), blurRadius: 18, offset: Offset(0, 8)),
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
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                            Text(
                              'Add, edit, delete, and manage activities',
                              style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Activity', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(_applyFilter),
                decoration: InputDecoration(
                  hintText: 'Search activities by name, code, or description...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0BAC9)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF5B6B86)),
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

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('No activities found.', style: TextStyle(color: Color(0xFF5B6B86))),
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
                              onManageSlots: () => _showManageSlotsDialog(_filtered[i]),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onEdit,
    required this.onDelete,
    required this.onManageSlots,
  });

  final Activity activity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageSlots;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x120D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activity.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(activity.code,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E6BFF))),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.group_outlined, size: 16, color: Color(0xFF5B6B86)),
            const SizedBox(width: 6),
            Text('Total Capacity: ${activity.totalCapacity} participants',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF5B6B86)),
            const SizedBox(width: 6),
            Text('${activity.availableSlotsCount} slot${activity.availableSlotsCount == 1 ? '' : 's'} available',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
          ]),
          if (activity.location != null && activity.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF5B6B86)),
              const SizedBox(width: 6),
              Text(activity.location!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
            ]),
          ],
          if (activity.description != null && activity.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(activity.description!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A96A8))),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: const Text('Manage Slots', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            if (activity.whatsappLink != null) _viewRow('WhatsApp', activity.whatsappLink!),
            if (activity.description != null) _viewRow('Description', activity.description!),
            _viewRow('Total Capacity', '${activity.totalCapacity} participants'),
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

  Widget _viewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Add / Edit Activity Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivityFormDialog extends StatefulWidget {
  const _ActivityFormDialog({required this.controller, this.activity});
  final AppController controller;
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
  bool _saving = false;

  bool get _isEdit => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _nameCtrl     = TextEditingController(text: a?.name ?? '');
    _codeCtrl     = TextEditingController(text: a?.code ?? '');
    _waCtrl       = TextEditingController(text: a?.whatsappLink ?? '');
    _descCtrl     = TextEditingController(text: a?.description ?? '');
    _locationCtrl = TextEditingController(text: a?.location ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose();
    _waCtrl.dispose();   _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final Activity result;
      if (_isEdit) {
        result = await widget.controller.apiService.updateActivity(
          token:        widget.controller.token!,
          id:           widget.activity!.id,
          name:         _nameCtrl.text.trim(),
          code:         _codeCtrl.text.trim(),
          whatsappLink: _waCtrl.text.trim(),
          description:  _descCtrl.text.trim(),
          location:     _locationCtrl.text.trim(),
        );
      } else {
        result = await widget.controller.apiService.createActivity(
          token:        widget.controller.token!,
          name:         _nameCtrl.text.trim(),
          code:         _codeCtrl.text.trim(),
          whatsappLink: _waCtrl.text.trim(),
          description:  _descCtrl.text.trim(),
          location:     _locationCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                        Text(_isEdit ? 'Edit Activity' : 'Add New Activity',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(
                          _isEdit ? 'Update the activity details' : 'Enter the details of the new curriculum activity',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DialogField(
                label: 'Activity Name *',
                controller: _nameCtrl,
                hint: 'Enter activity name',
                validator: (v) => v == null || v.trim().isEmpty ? 'Activity name is required.' : null,
              ),
              const SizedBox(height: 14),
              _DialogField(
                label: _isEdit ? 'Activity Code *' : 'Activity Code (optional - auto-generated if empty)',
                controller: _codeCtrl,
                hint: 'e.g., LW202',
                validator: _isEdit
                    ? (v) => v == null || v.trim().isEmpty ? 'Code is required.' : null
                    : null,
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
                helperText: 'Enter the venue name where the activity will be held',
                validator: (v) => v == null || v.trim().isEmpty ? 'Location is required.' : null,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Save Changes' : 'Add Activity',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  child: Text('Delete Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
                  Text('Activity: ${activity.name}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Code: ${activity.code}',
                      style: const TextStyle(color: Color(0xFF5B6B86))),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.maxLines = 1,
    this.helperText,
    this.validator,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final String? helperText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
            helperText: helperText,
            helperStyle: const TextStyle(color: Color(0xFF8A96A8), fontSize: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFD),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
