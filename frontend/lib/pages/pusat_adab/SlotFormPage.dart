import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity.dart';
import '../../models/activity_slot.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Formats an ISO date string (e.g. "2025-06-14") as a full readable date
/// with weekday, e.g. "Saturday, June 14, 2025". Used in the existing slots
/// table and the attendance code / delete confirmation dialogs.
String _formatDate(String dateStr) {
  final d = DateTime.parse(dateStr);
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Converts a [DateTime] to the `yyyy-MM-dd` format expected by the
/// add/update slot API endpoints.
String _apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Converts a [DateTime] to the `dd/mm/yyyy` format shown in the date
/// picker fields.
String _displayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Parses a 12-hour time string like "8:00 AM" or "5:30 PM" (as stored in
/// the slot's `time` range, e.g. "8:00 AM - 5:30 PM") back into a
/// [TimeOfDay]. Used by [_EditSlotDialogState] to pre-fill the time pickers
/// from the existing slot's time range.
TimeOfDay _parseTime12h(String s) {
  final parts = s.trim().split(RegExp(r'[:\s]'));
  var hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final period = parts[2].toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SlotFormPage
// ═══════════════════════════════════════════════════════════════════════════════

/// Pusat Adab's "Manage Time Slots" dialog for a single [activity].
///
/// Shown as a full dialog (not a page route) so it can be opened from the
/// activity management screen and return the updated [Activity] (with its
/// new/edited/removed slots) via [Navigator.pop] when closed.
///
/// Contains:
///  - An "Add New Slot" form (date, capacity, start/end time) — see [_addSlot].
///  - An "Existing Slots" table listing every slot for this activity, with
///    edit ([_editSlot]) and delete ([_confirmDeleteSlot]) actions per row.
class SlotFormPage extends StatefulWidget {
  const SlotFormPage({
    super.key,
    required this.activity,
    required this.controller,
  });

  /// The activity whose slots are being managed. Its [Activity.slots] list
  /// is shown in the "Existing Slots" table and updated locally as slots
  /// are added/edited/deleted.
  final Activity activity;
  final AppController controller;

  @override
  State<SlotFormPage> createState() => _SlotFormPageState();
}

class _SlotFormPageState extends State<SlotFormPage> {
  /// Local mutable copy of [SlotFormPage.activity]. Updated in place
  /// whenever a slot is added, edited, or deleted so the table re-renders
  /// without re-fetching the activity from the server. Returned to the
  /// caller via [_goBack] when the dialog is closed.
  late Activity _activity;

  // ── "Add New Slot" form state ───────────────────────────────────────────────
  /// Date selected for the new slot via [_pickDate]. Null until chosen.
  DateTime? _selectedDate;
  /// Start time selected for the new slot via [_pickTime].
  TimeOfDay? _startTime;
  /// End time selected for the new slot via [_pickTime].
  TimeOfDay? _endTime;
  /// Capacity (max registrations) for the new slot.
  final _capacityCtrl = TextEditingController();
  /// True while [_addSlot] is submitting to the API — disables the button.
  bool _addingSlot = false;

  // ── Form validation errors ──────────────────────────────────────────────────
  /// Set when no date has been selected for the new slot.
  String? _dateError;
  /// Set when the capacity field is empty or not a positive integer.
  String? _capacityError;
  /// Set when start/end time has not been fully selected.
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    super.dispose();
  }

  /// Formats a [TimeOfDay] as a 12-hour string, e.g. "8:00 AM" or "5:30 PM".
  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$min $p';
  }

  /// Opens the date picker for the new slot. Allows any date from tomorrow
  /// up to 2 years out — slots cannot be created for today/the past.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateError = null;
      });
    }
  }

  /// Opens the time picker for the new slot's start or end time, seeded
  /// with sensible defaults (8:00 AM / 5:00 PM) the first time it's opened.
  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _timeError = null;
      });
    }
  }

  /// Validates the "Add New Slot" form, then calls the add-slot API.
  ///
  /// Validation rules (set [_dateError]/[_capacityError]/[_timeError]):
  ///  - A date must be selected.
  ///  - Capacity must be a positive integer.
  ///  - Both start and end time must be selected.
  ///
  /// On success, appends the new slot to [_activity], clears the form, and
  /// shows [_AttendanceCodeDialog] so Pusat Adab can note down the generated
  /// attendance code for the new slot.
  Future<void> _addSlot() async {
    final capText = _capacityCtrl.text.trim();
    final capacity = int.tryParse(capText);

    setState(() {
      _dateError = _selectedDate == null ? 'Please select a date.' : null;
      _capacityError = capText.isEmpty
          ? 'Enter capacity'
          : (capacity == null || capacity <= 0)
              ? 'Invalid input'
              : null;
      _timeError = (_startTime == null || _endTime == null)
          ? 'Please select both start and end time.'
          : null;
    });

    // Stop here if any validation error was set above.
    if (_dateError != null || _capacityError != null || _timeError != null) {
      return;
    }

    // Combine start/end times into the "8:00 AM - 5:00 PM" format the
    // backend stores for a slot's time range.
    final timeText = '${_fmtTime(_startTime!)} - ${_fmtTime(_endTime!)}';
    setState(() => _addingSlot = true);
    try {
      final slot = await widget.controller.apiService.addSlot(
        token: widget.controller.token!,
        activityId: _activity.id,
        date: _apiDate(_selectedDate!),
        time: timeText,
        capacity: capacity!,
      );
      // Append the newly created slot (with its server-assigned attendance
      // code) to the local activity copy so the table updates immediately.
      final updated = _activity.copyWith(slots: [..._activity.slots, slot]);
      setState(() {
        _activity = updated;
        _selectedDate = null;
        _startTime = null;
        _endTime = null;
        _capacityCtrl.clear();
      });
      if (!mounted) return;
      // Show the generated attendance code so Pusat Adab can share it.
      await showDialog<void>(
        context: context,
        builder: (_) =>
            _AttendanceCodeDialog(slot: slot, activityName: _activity.name),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _addingSlot = false);
    }
  }

  /// Opens [_EditSlotDialog] for [slot]. If the dialog returns an updated
  /// slot (i.e. the save succeeded), replaces the matching slot in
  /// [_activity] so the table reflects the new date/time/capacity.
  Future<void> _editSlot(ActivitySlot slot) async {
    final updated = await showDialog<ActivitySlot>(
      context: context,
      builder: (_) => _EditSlotDialog(activityId: _activity.id, slot: slot, controller: widget.controller),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _activity = _activity.copyWith(
        slots: _activity.slots.map((s) => s.id == updated.id ? updated : s).toList(),
      );
    });
  }

  /// Shows [_DeleteSlotDialog] to confirm deletion of [slot], then calls
  /// [_deleteSlot] if the user confirms.
  Future<void> _confirmDeleteSlot(ActivitySlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSlotDialog(slot: slot),
    );
    if (confirmed == true) _deleteSlot(slot);
  }

  /// Calls the delete-slot API for [slot] and removes it from [_activity]'s
  /// local slot list on success. Shows a snackbar if the API call fails
  /// (e.g. the slot has registered students and the backend rejects it).
  Future<void> _deleteSlot(ActivitySlot slot) async {
    try {
      await widget.controller.apiService.deleteSlot(
        token: widget.controller.token!,
        activityId: _activity.id,
        slotId: slot.id,
      );
      final updated = _activity.copyWith(
        slots: _activity.slots.where((s) => s.id != slot.id).toList(),
      );
      setState(() => _activity = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Closes the dialog, returning the (possibly updated) [_activity] to the
  /// caller so the activity management screen can refresh its slot list.
  void _goBack() => Navigator.of(context).pop(_activity);

  @override
  Widget build(BuildContext context) {
    // Intercept back navigation so closing always returns the (possibly
    // updated) activity via _goBack, instead of popping with no result.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Time Slots',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '${_activity.name} (${_activity.code})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2E6BFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _goBack,
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF5B6B86),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // ── Scrollable content ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── "Add New Slot" form ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add New Slot',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Row: Date + Capacity
                          Row(
                            children: [
                              // Date picker
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Date *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: _pickDate,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _dateError != null
                                                ? const Color(0xFFFF4D4F)
                                                : const Color(0xFFD6E0F0),
                                            width: _dateError != null ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 14,
                                              color: Color(0xFF5B6B86),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _selectedDate != null
                                                  ? _displayDate(_selectedDate!)
                                                  : 'dd/mm/yyyy',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedDate != null
                                                    ? const Color(0xFF111827)
                                                    : const Color(0xFFB0BAC9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_dateError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _dateError!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFFF4D4F),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Capacity input
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Capacity *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _capacityCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 12),
                                      onChanged: (_) {
                                        if (_capacityError != null) {
                                          setState(() => _capacityError = null);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'e.g. 30',
                                        hintStyle: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFB0BAC9),
                                        ),
                                        errorText: _capacityError,
                                        errorStyle: const TextStyle(
                                          fontSize: 11,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 11,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFD6E0F0),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFD6E0F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E5BFF),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Time range
                          const Text(
                            'Time Range *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Start time
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickTime(isStart: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _timeError != null
                                            ? const Color(0xFFFF4D4F)
                                            : (_startTime != null
                                                  ? const Color(0xFF1E5BFF)
                                                  : const Color(0xFFD6E0F0)),
                                        width:
                                            (_startTime != null ||
                                                _timeError != null)
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_outlined,
                                          size: 14,
                                          color: Color(0xFF5B6B86),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _startTime != null
                                              ? _fmtTime(_startTime!)
                                              : 'Start',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _startTime != null
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: _startTime != null
                                                ? const Color(0xFF111827)
                                                : const Color(0xFFB0BAC9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '→',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        (_startTime != null && _endTime != null)
                                        ? const Color(0xFF1E5BFF)
                                        : const Color(0xFFB0BAC9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              // End time
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickTime(isStart: false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _timeError != null
                                            ? const Color(0xFFFF4D4F)
                                            : (_endTime != null
                                                  ? const Color(0xFF1E5BFF)
                                                  : const Color(0xFFD6E0F0)),
                                        width:
                                            (_endTime != null ||
                                                _timeError != null)
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_outlined,
                                          size: 14,
                                          color: Color(0xFF5B6B86),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _endTime != null
                                              ? _fmtTime(_endTime!)
                                              : 'End',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _endTime != null
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: _endTime != null
                                                ? const Color(0xFF111827)
                                                : const Color(0xFFB0BAC9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_timeError != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _timeError!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF4D4F),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Submit button — validates and calls _addSlot.
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _addingSlot ? null : _addSlot,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1E5BFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _addingSlot
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Add Slot',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── "Existing Slots" table ───────────────────────────────
                    Text(
                      'Existing Slots (${_activity.slots.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_activity.slots.isEmpty)
                      const Text(
                        'No slots yet.',
                        style: TextStyle(color: Color(0xFF8A96A8)),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        // Horizontal scroll lets the table fit narrow dialog
                        // widths without truncating columns.
                        child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFD),
                          ),
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 64,
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Time',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Cap',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Reg',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Code',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Action',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                          // One row per slot: date, time, capacity,
                          // registered count, availability badge,
                          // attendance code, and edit/delete actions.
                          rows: _activity.slots.map((slot) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    _formatDate(slot.date),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    slot.time,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${slot.capacity}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${slot.registered}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                // "Available"/"Full" badge — slot.isAvailable
                                // compares registered count against capacity.
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: slot.isAvailable
                                          ? const Color(0xFFE7F9EE)
                                          : const Color(0xFFFFEDEE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      slot.isAvailable ? 'Available' : 'Full',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: slot.isAvailable
                                            ? const Color(0xFF0EAF4B)
                                            : const Color(0xFFFF4D4F),
                                      ),
                                    ),
                                  ),
                                ),
                                // Attendance code badge — tapping it re-opens
                                // _AttendanceCodeDialog to view the code again.
                                // Shows '-' if no code has been generated yet.
                                DataCell(
                                  slot.attendanceCode != null
                                      ? GestureDetector(
                                          onTap: () => showDialog<void>(
                                            context: context,
                                            builder: (_) =>
                                                _AttendanceCodeDialog(
                                                  slot: slot,
                                                  activityName: _activity.name,
                                                ),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF4FF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFF2E6BFF),
                                              ),
                                            ),
                                            child: Text(
                                              slot.attendanceCode!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1E5BFF),
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8A96A8),
                                          ),
                                        ),
                                ),
                                // Edit / delete action icons for this slot.
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          color: Color(0xFF1E5BFF),
                                          size: 18,
                                        ),
                                        onPressed: () => _editSlot(slot),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFFF4D4F),
                                          size: 18,
                                        ),
                                        onPressed: () => _confirmDeleteSlot(slot),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            // Close button returns the (possibly updated) activity to the caller.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goBack,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w700),
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
// Attendance Code Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Displays the auto-generated attendance code for a newly created (or
/// existing) slot, so Pusat Adab can share it verbally with students on
/// the day of the event.
///
/// Shown after [_SlotFormPageState._addSlot] succeeds, and also re-openable
/// from the "Code" column of the existing slots table.
class _AttendanceCodeDialog extends StatelessWidget {
  const _AttendanceCodeDialog({required this.slot, required this.activityName});
  final ActivitySlot slot;
  final String activityName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE7F9EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF0EAF4B),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Slot Created!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              activityName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(slot.date)}  •  ${slot.time}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Attendance Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6B86),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E6BFF), width: 1.5),
              ),
              child: Text(
                slot.attendanceCode ?? '-',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E5BFF),
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Share this code verbally with students on the day of the event.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF8A96A8)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
// Delete Slot Confirmation Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Confirmation dialog shown before permanently deleting [slot].
///
/// If [slot.registered] is greater than 0, shows a warning that students
/// are already registered — deletion still proceeds if the user confirms,
/// but the backend may reject it (handled by
/// [_SlotFormPageState._deleteSlot]'s catch block).
///
/// Pops with `true` (confirmed) or `false`/`null` (cancelled).
class _DeleteSlotDialog extends StatelessWidget {
  const _DeleteSlotDialog({required this.slot});
  final ActivitySlot slot;

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
                    'Delete Slot',
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
              'Are you sure you want to delete this slot? This action cannot be undone.',
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
                    _formatDate(slot.date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.time,
                    style: const TextStyle(color: Color(0xFF5B6B86)),
                  ),
                ],
              ),
            ),
            // Extra warning when students have already registered for this
            // slot — deletion is still allowed here but flagged to the user.
            if (slot.registered > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${slot.registered} student(s) are already registered for this slot.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF4D4F), fontWeight: FontWeight.w600),
                ),
              ),
            ],
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
// Edit Slot Dialog
// ═══════════════════════════════════════════════════════════════════════════════

/// Dialog for editing an existing slot's date, time range, and capacity.
///
/// Pre-fills its fields from [slot] (parsing the stored "8:00 AM - 5:00 PM"
/// time range back into [TimeOfDay] values via [_parseTime12h]). On save,
/// calls the update-slot API and pops with the updated [ActivitySlot] so
/// [_SlotFormPageState._editSlot] can replace the row in the table.
class _EditSlotDialog extends StatefulWidget {
  const _EditSlotDialog({
    required this.activityId,
    required this.slot,
    required this.controller,
  });

  final int activityId;
  final ActivitySlot slot;
  final AppController controller;

  @override
  State<_EditSlotDialog> createState() => _EditSlotDialogState();
}

class _EditSlotDialogState extends State<_EditSlotDialog> {
  /// Date for the slot, pre-filled from [_EditSlotDialog.slot.date].
  late DateTime _selectedDate;
  /// Start time, parsed from the slot's existing time range.
  late TimeOfDay _startTime;
  /// End time, parsed from the slot's existing time range.
  late TimeOfDay _endTime;
  /// Capacity field, pre-filled with the slot's current capacity.
  late final TextEditingController _capacityCtrl;
  /// True while [_save] is submitting to the API.
  bool _saving = false;

  /// Validation error for the capacity field (empty, non-numeric, or below
  /// the number of students already registered).
  String? _capacityError;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.slot.date);
    final halves = widget.slot.time.split(' - ');
    _startTime = _parseTime12h(halves[0]);
    _endTime = halves.length > 1 ? _parseTime12h(halves[1]) : _startTime;
    _capacityCtrl = TextEditingController(text: '${widget.slot.capacity}');
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$min $p';
  }

  Future<void> _pickDate() async {
    final firstDate = _selectedDate.isBefore(DateTime.now()) ? _selectedDate : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final capText = _capacityCtrl.text.trim();
    final capacity = int.tryParse(capText);

    setState(() {
      _capacityError = capText.isEmpty
          ? 'Enter capacity'
          : (capacity == null || capacity <= 0)
              ? 'Invalid input'
              : (capacity < widget.slot.registered)
                  ? 'Cannot be less than ${widget.slot.registered} registered'
                  : null;
    });

    if (_capacityError != null) return;

    final timeText = '${_fmtTime(_startTime)} - ${_fmtTime(_endTime)}';
    setState(() => _saving = true);
    try {
      final updated = await widget.controller.apiService.updateSlot(
        token: widget.controller.token!,
        activityId: widget.activityId,
        slotId: widget.slot.id,
        date: _apiDate(_selectedDate),
        time: timeText,
        capacity: capacity!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Slot',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date + Capacity row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD6E0F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF5B6B86)),
                              const SizedBox(width: 6),
                              Text(
                                _displayDate(_selectedDate),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Capacity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _capacityCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        onChanged: (_) {
                          if (_capacityError != null) setState(() => _capacityError = null);
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. 30',
                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB0BAC9)),
                          errorText: _capacityError,
                          errorStyle: const TextStyle(fontSize: 11),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Time range
            const Text('Time Range *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E5BFF), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_outlined, size: 14, color: Color(0xFF5B6B86)),
                          const SizedBox(width: 6),
                          Text(
                            _fmtTime(_startTime),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(fontSize: 16, color: Color(0xFF1E5BFF), fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E5BFF), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_outlined, size: 14, color: Color(0xFF5B6B86)),
                          const SizedBox(width: 6),
                          Text(
                            _fmtTime(_endTime),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
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
