// lecturer_attendance_record.dart — Boundary Screen
// Requirement ID : SAMS-PACK-409
// Responsibility : Displays attendance records for a selected attendance session,
//                  with search by student name/matric and filter by status.
//
// Attributes:
//   attendanceRecord  List<AttendanceSubmission>
//   searchKeyword     String
//   filterStatus      String
//
// Methods:
//   render()                                       — Renders attendance record interface.
//   loadAttendanceRecord(attendance_session_id)    — Retrieves attendance records.
//   searchStudent(keyword)                         — Searches record by student name or ID.
//   filterByStatus(status)                         — Filters record by attendance status.

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'lecturer_attendance_report.dart';

class LecturerAttendanceRecord extends StatefulWidget {
  final AttendanceSessionModel session;
  final ClassScheduleModel schedule;
  const LecturerAttendanceRecord({super.key, required this.session, required this.schedule});

  @override
  State<LecturerAttendanceRecord> createState() => _LecturerAttendanceRecordState();
}

class _LecturerAttendanceRecordState extends State<LecturerAttendanceRecord> {
  List<AttendanceSubmissionModel> _all      = [];
  List<AttendanceSubmissionModel> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    // loadAttendanceRecord() — SAMS-PACK-409
    _loadRecord();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // loadAttendanceRecord(attendance_session_id) — List<AttendanceSubmission>
  // SAMS-PACK-409
  Future<void> _loadRecord() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getAttendanceRecord(widget.session.attendanceSessionId);
      if (res['status'] == 200) {
        _all = (res['submissions'] as List)
            .map((j) => AttendanceSubmissionModel.fromJson(j))
            .toList();
        _applyFilter();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  // searchStudent(keyword) + filterByStatus(status) — SAMS-PACK-409
  void _applyFilter() {
    final kw = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((sub) {
        final matchSearch = kw.isEmpty ||
            (sub.studentName?.toLowerCase().contains(kw) ?? false) ||
            (sub.studentMatric?.toLowerCase().contains(kw) ?? false);
        final matchStatus = _filterStatus == 'all' || sub.attendanceStatus == _filterStatus;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  // render() — void  (SAMS-PACK-409)
  @override
  Widget build(BuildContext context) {
    final present = _all.where((s) => s.attendanceStatus == 'present').length;
    final total   = _all.length;
    final pct     = total > 0 ? present / total : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Attendance Record',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const LecturerAttendanceReport(user: null))),
            icon: const Icon(Icons.bar_chart_outlined, size: 16),
            label: const Text('Reports', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E5BFF)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5BFF)))
        : Column(children: [

            // Header section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.schedule.courseName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('${widget.schedule.section}  ·  ${widget.session.sessionDate}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
                const SizedBox(height: 14),

                // Stats row
                Row(children: [
                  _StatBox(label: 'Present', value: '$present', color: const Color(0xFF22C55E)),
                  const SizedBox(width: 10),
                  _StatBox(label: 'Total', value: '$total', color: const Color(0xFF1E5BFF)),
                  const SizedBox(width: 10),
                  _StatBox(
                    label: 'Rate',
                    value: '${(pct * 100).toStringAsFixed(0)}%',
                    color: pct >= 0.8
                        ? const Color(0xFF22C55E)
                        : pct >= 0.5
                          ? const Color(0xFFC47F00)
                          : const Color(0xFFFF3B30),
                  ),
                ]),
                const SizedBox(height: 14),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE8EDF6),
                    valueColor: AlwaysStoppedAnimation(
                      pct >= 0.8
                          ? const Color(0xFF22C55E)
                          : pct >= 0.5
                            ? const Color(0xFFC47F00)
                            : const Color(0xFFFF3B30),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // searchStudent() — SAMS-PACK-409
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or matric number...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                    prefixIcon: const Icon(Icons.search_outlined, size: 18, color: Color(0xFF5B6B86)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFD),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EDF6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8EDF6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // filterByStatus() — SAMS-PACK-409
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in ['all', 'present', 'rejected'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: f == 'all' ? 'All' : f[0].toUpperCase() + f.substring(1),
                          selected: _filterStatus == f,
                          onTap: () { setState(() => _filterStatus = f); _applyFilter(); },
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
              ]),
            ),

            const Divider(height: 1, color: Color(0xFFE8EDF6)),

            // Record list
            Expanded(child: _filtered.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.search_off_outlined, size: 40, color: Color(0xFF5B6B86)),
                  SizedBox(height: 10),
                  Text('No records found',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                  SizedBox(height: 4),
                  Text('Try adjusting your search or filter',
                    style: TextStyle(color: Color(0xFF5B6B86), fontSize: 13)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final sub = _filtered[i];
                    final isPresent = sub.attendanceStatus == 'present';
                    final color = isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE8EDF6)),
                        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: Text(
                            (sub.studentName ?? '?')[0].toUpperCase(),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sub.studentName ?? '—',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                          const SizedBox(height: 2),
                          Text(sub.studentMatric ?? '',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _StatusPill(status: sub.attendanceStatus),
                          const SizedBox(height: 4),
                          Text(
                            sub.submittedAt.length >= 16 ? sub.submittedAt.substring(11, 16) : '',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86)),
                          ),
                        ]),
                      ]),
                    );
                  },
                ),
            ),
          ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75))),
      ]),
    ));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E5BFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1E5BFF) : const Color(0xFFE8EDF6),
          ),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF5B6B86),
          )),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPresent = status == 'present';
    final color = isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPresent ? 'Present' : 'Rejected',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
