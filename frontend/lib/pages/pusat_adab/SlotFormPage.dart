import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/activity.dart';
import '../../models/activity_slot.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatDate(String dateStr) {
  final d = DateTime.parse(dateStr);
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ═══════════════════════════════════════════════════════════════════════════════
// SlotFormPage
// ═══════════════════════════════════════════════════════════════════════════════

class SlotFormPage extends StatefulWidget {
  const SlotFormPage({
    super.key,
    required this.activity,
    required this.controller,
  });

  final Activity activity;
  final AppController controller;

  @override
  State<SlotFormPage> createState() => _SlotFormPageState();
}

class _SlotFormPageState extends State<SlotFormPage> {
  late Activity _activity;

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _capacityCtrl = TextEditingController();
  bool _addingSlot = false;

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

  String _fmtTime(TimeOfDay t) {
    final h   = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final p   = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$min $p';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 8,  minute: 0))
        : (_endTime   ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Select Start Time' : 'Select End Time',
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _addSlot() async {
    final capText  = _capacityCtrl.text.trim();
    final capacity = int.tryParse(capText);

    if (_selectedDate == null || _startTime == null || _endTime == null ||
        capacity == null || capacity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in date, start time, end time, and capacity.')),
      );
      return;
    }

    final timeText = '${_fmtTime(_startTime!)} - ${_fmtTime(_endTime!)}';
    setState(() => _addingSlot = true);
    try {
      final slot = await widget.controller.apiService.addSlot(
        token:      widget.controller.token!,
        activityId: _activity.id,
        date:       _apiDate(_selectedDate!),
        time:       timeText,
        capacity:   capacity,
      );
      final updated = _activity.copyWith(slots: [..._activity.slots, slot]);
      setState(() {
        _activity     = updated;
        _selectedDate = null;
        _startTime    = null;
        _endTime      = null;
        _capacityCtrl.clear();
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _AttendanceCodeDialog(
          slot:         slot,
          activityName: _activity.name,
        ),
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

  Future<void> _deleteSlot(ActivitySlot slot) async {
    try {
      await widget.controller.apiService.deleteSlot(
        token:      widget.controller.token!,
        activityId: _activity.id,
        slotId:     slot.id,
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

  void _goBack() => Navigator.of(context).pop(_activity);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manage Time Slots',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                          ),
                          Text(
                            '${_activity.name} (${_activity.code})',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF2E6BFF), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add New Slot form
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Add New Slot',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                                      const Text('Date *',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                              const Icon(Icons.calendar_today_outlined,
                                                  size: 14, color: Color(0xFF5B6B86)),
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
                                      const Text('Capacity *',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _capacityCtrl,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 12),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 30',
                                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFB0BAC9)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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
                                            borderSide:
                                                const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
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
                            const Text('Time Range *',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Start time
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _pickTime(isStart: true),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _startTime != null
                                              ? const Color(0xFF1E5BFF)
                                              : const Color(0xFFD6E0F0),
                                          width: _startTime != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_outlined,
                                              size: 14, color: Color(0xFF5B6B86)),
                                          const SizedBox(width: 6),
                                          Text(
                                            _startTime != null ? _fmtTime(_startTime!) : 'Start',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '→',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: (_startTime != null && _endTime != null)
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
                                      padding:
                                          const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _endTime != null
                                              ? const Color(0xFF1E5BFF)
                                              : const Color(0xFFD6E0F0),
                                          width: _endTime != null ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_outlined,
                                              size: 14, color: Color(0xFF5B6B86)),
                                          const SizedBox(width: 6),
                                          Text(
                                            _endTime != null ? _fmtTime(_endTime!) : 'End',
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
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _addingSlot ? null : _addSlot,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E5BFF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: _addingSlot
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.add, size: 18),
                                label: const Text('Add Slot',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Existing slots table
                      Text(
                        'Existing Slots (${_activity.slots.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 10),

                      if (_activity.slots.isEmpty)
                        const Text('No slots yet.',
                            style: TextStyle(color: Color(0xFF8A96A8)))
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor:
                                WidgetStateProperty.all(const Color(0xFFF8FAFD)),
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 64,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Date',   style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Time',   style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Cap',    style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Reg',    style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Code',   style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: _activity.slots.map((slot) {
                              return DataRow(cells: [
                                DataCell(Text(_formatDate(slot.date),
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(slot.time,
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text('${slot.capacity}',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text('${slot.registered}',
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                )),
                                DataCell(
                                  slot.attendanceCode != null
                                      ? GestureDetector(
                                          onTap: () => showDialog<void>(
                                            context: context,
                                            builder: (_) => _AttendanceCodeDialog(
                                              slot:         slot,
                                              activityName: _activity.name,
                                            ),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF4FF),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF2E6BFF)),
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
                                      : const Text('-',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF8A96A8))),
                                ),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFFF4D4F), size: 18),
                                  onPressed: () => _deleteSlot(slot),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
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
// Attendance Code Dialog
// ═══════════════════════════════════════════════════════════════════════════════

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
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF0EAF4B), size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'Slot Created!',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5B6B86)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
