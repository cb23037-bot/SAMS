import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/class_attendance_submission.dart';
import '../../models/class_schedule.dart';

/// Shows the present/rejected/absent breakdown for an attendance session.
/// SAMS-PACK-409: supports searchStudent(keyword) and filterByStatus(status).
class LecturerAttendanceRecordPage extends StatefulWidget {
  const LecturerAttendanceRecordPage({
    super.key,
    required this.controller,
    required this.sessionId,
    required this.schedule,
  });

  final AppController controller;
  final int sessionId;
  final ClassScheduleModel schedule;

  @override
  State<LecturerAttendanceRecordPage> createState() => _LecturerAttendanceRecordPageState();
}

class _LecturerAttendanceRecordPageState extends State<LecturerAttendanceRecordPage> {
  late Future<AttendanceRecordModel> _recordFuture;

  /// SAMS-PACK-409: searchStudent(keyword) — filters list by name or matric no.
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  /// SAMS-PACK-409: filterByStatus(status) — 'all', 'present', 'rejected', 'absent'.
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _recordFuture = loadAttendanceRecord(widget.sessionId);
    _searchController.addListener(() {
      setState(() => _searchKeyword = _searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// SAMS-PACK-409: loadAttendanceRecord(attendance_session_id)
  /// Retrieves the full attendance record for a session — present, rejected,
  /// and absent student lists — from the backend API.
  /// Returns: List<AttendanceSubmission> (wrapped in AttendanceRecordModel).
  Future<AttendanceRecordModel> loadAttendanceRecord(int attendanceSessionId) {
    return widget.controller.apiService.getAttendanceRecord(
      token: widget.controller.token!,
      sessionId: attendanceSessionId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _recordFuture = loadAttendanceRecord(widget.sessionId);
    });
    await _recordFuture;
  }

  /// SAMS-PACK-409: searchStudent(keyword)
  /// Searches the attendance record by student name or matric number.
  /// Filters any list of student entries whose name or matric no contains [keyword].
  /// Returns: List<AttendanceSubmission> — matching entries only.
  List<T> searchStudent<T>(List<T> list, String Function(T) getName, String Function(T) getMatric) {
    if (_searchKeyword.isEmpty) return list;
    return list.where((item) {
      return getName(item).toLowerCase().contains(_searchKeyword) ||
          getMatric(item).toLowerCase().contains(_searchKeyword);
    }).toList();
  }

  /// SAMS-PACK-409: filterByStatus(status)
  /// Filters the attendance record by attendance status.
  /// [status] is one of: 'all', 'present', 'rejected', 'absent'.
  /// Returns: List<AttendanceSubmission> — entries matching the given status.
  bool filterByStatus(String status) {
    if (_statusFilter == 'all') return true;
    return _statusFilter == status;
  }

  /// SAMS-PACK-409: render()
  /// Renders the attendance record interface — session info card, count summary,
  /// search bar, status filter chips, and sectioned student lists.
  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: Text(
          '${schedule.courseCode} Record',
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<AttendanceRecordModel>(
          future: _recordFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF5B6B86)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: OutlinedButton(onPressed: _refresh, child: const Text('Retry'))),
                ],
              );
            }

            final record = snapshot.data!;

            // Apply search filter to each section.
            final filteredPresent = searchStudent<ClassAttendanceSubmissionModel>(record.present, (s) => s.studentName, (s) => s.matricNo);
            final filteredRejected = searchStudent<ClassAttendanceSubmissionModel>(record.rejected, (s) => s.studentName, (s) => s.matricNo);
            final filteredAbsent = searchStudent<AbsentStudentModel>(record.absent, (s) => s.name, (s) => s.matricNo);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Session info card
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${schedule.courseCode} - ${schedule.courseName}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Session Date: ${record.session.sessionDate}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${record.session.status == 'active' ? 'Active' : 'Closed'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _CountCard(
                        label: 'Present',
                        value: record.present.length.toString(),
                        color: const Color(0xFF22C55E),
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CountCard(
                        label: 'Rejected',
                        value: record.rejected.length.toString(),
                        color: const Color(0xFFFF3B30),
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CountCard(
                        label: 'Absent',
                        value: record.absent.length.toString(),
                        color: const Color(0xFF8A96A8),
                        icon: Icons.person_off_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // SAMS-PACK-409: searchStudent() — search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or matric no...',
                    hintStyle: const TextStyle(color: Color(0xFF8A96A8)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8A96A8)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),

                const SizedBox(height: 12),

                // SAMS-PACK-409: filterByStatus() — status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _statusFilter == 'all',
                        color: const Color(0xFF2E6BFF),
                        onTap: () => setState(() => _statusFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Present',
                        selected: _statusFilter == 'present',
                        color: const Color(0xFF22C55E),
                        onTap: () => setState(() => _statusFilter = 'present'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Rejected',
                        selected: _statusFilter == 'rejected',
                        color: const Color(0xFFFF3B30),
                        onTap: () => setState(() => _statusFilter = 'rejected'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Absent',
                        selected: _statusFilter == 'absent',
                        color: const Color(0xFF8A96A8),
                        onTap: () => setState(() => _statusFilter = 'absent'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (filterByStatus('present')) ...[
                  _SectionList(
                    title: 'Present',
                    color: const Color(0xFF22C55E),
                    icon: Icons.check_circle,
                    emptyText: 'No students marked present.',
                    children: filteredPresent.map((ClassAttendanceSubmissionModel s) => _StudentTile(name: s.studentName, matricNo: s.matricNo)).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                if (filterByStatus('rejected')) ...[
                  _SectionList(
                    title: 'Rejected',
                    color: const Color(0xFFFF3B30),
                    icon: Icons.cancel,
                    emptyText: 'No rejected submissions.',
                    children: filteredRejected.map((ClassAttendanceSubmissionModel s) => _StudentTile(name: s.studentName, matricNo: s.matricNo)).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                if (filterByStatus('absent')) ...[
                  _SectionList(
                    title: 'Absent',
                    color: const Color(0xFF8A96A8),
                    icon: Icons.person_off,
                    emptyText: 'No absent students.',
                    children: filteredAbsent.map((AbsentStudentModel s) => _StudentTile(name: s.name, matricNo: s.matricNo)).toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0)),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF5B6B86),
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.color,
    required this.icon,
    required this.children,
    required this.emptyText,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<Widget> children;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              '$title (${children.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Center(child: Text(emptyText, style: const TextStyle(color: Color(0xFF5B6B86)))),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.name, required this.matricNo});

  final String name;
  final String matricNo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
        child: const Icon(Icons.person, color: Colors.white, size: 18),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(matricNo),
    );
  }
}
