import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import 'lecturer_attendance_record.dart';

class LecturerActiveSession extends StatefulWidget {
  final ClassScheduleModel schedule;
  final AttendanceSessionModel session;
  const LecturerActiveSession({super.key, required this.schedule, required this.session});

  @override
  State<LecturerActiveSession> createState() => _LecturerActiveSessionState();
}

class _LecturerActiveSessionState extends State<LecturerActiveSession> {
  late AttendanceSessionModel _session;
  List<AttendanceSubmissionModel> _submissions = [];
  Timer? _timer;
  bool _closing  = false;
  int? _enrolledCount;
  bool _pollError = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadEnrolledCount();
    _loadLiveSubmissions();
    if (_session.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadLiveSubmissions());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadEnrolledCount() async {
    try {
      final res = await ApiService.getEnrolledCount(widget.schedule.scheduleId);
      if (res['status'] == 200 && mounted) {
        setState(() => _enrolledCount = res['enrolled_count']);
      }
    } catch (_) {}
  }

  Future<void> _loadLiveSubmissions() async {
    try {
      final res = await ApiService.getLiveSubmissions(_session.attendanceSessionId);
      if (!mounted) return;
      if (res['status'] == 200) {
        setState(() {
          _submissions = (res['submissions'] as List)
              .map((j) => AttendanceSubmissionModel.fromJson(j))
              .toList();
          _pollError = false;
        });
      } else {
        setState(() => _pollError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _pollError = true);
    }
  }

  Future<void> _generateCode() async {
    final res = await ApiService.generateCode(_session.attendanceSessionId);
    if (res['status'] == 200) {
      setState(() => _session = AttendanceSessionModel(
        attendanceSessionId: _session.attendanceSessionId,
        scheduleId:          _session.scheduleId,
        attendanceCode:      res['attendance_code'],
        sessionDate:         _session.sessionDate,
        startedAt:           _session.startedAt,
        closedAt:            _session.closedAt,
        status:              _session.status,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('New code generated: ${res['attendance_code']}'),
        backgroundColor: const Color(0xFF0D6B5E),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Close Session?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),
        content: const Text(
          'Students will no longer be able to submit attendance once the session is closed.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6B82), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8896AB))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Close Session'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _closing = true);

    final res = await ApiService.closeSession(_session.attendanceSessionId);
    setState(() => _closing = false);

    if (res['status'] == 200) {
      _timer?.cancel();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => LecturerAttendanceRecord(
          session: AttendanceSessionModel(
            attendanceSessionId: _session.attendanceSessionId,
            scheduleId:          _session.scheduleId,
            attendanceCode:      _session.attendanceCode,
            sessionDate:         _session.sessionDate,
            startedAt:           _session.startedAt,
            closedAt:            DateTime.now().toIso8601String(),
            status:              'closed',
          ),
          schedule: widget.schedule,
        ),
      ));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Failed to close session'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _submissions.where((s) => s.attendanceStatus == 'present').length;
    final total        = _enrolledCount ?? 0;
    final pct          = total > 0 ? presentCount / total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(
        title: const Text('Live Session'),
        actions: [
          if (_session.isActive)
            IconButton(
              icon: const Icon(Icons.refresh_outlined, size: 20),
              onPressed: _loadLiveSubmissions,
              tooltip: 'Refresh',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Session info
          _Card(child: Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _session.isActive
                    ? const Color(0xFFE8F5F2)
                    : const Color(0xFFF0F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _session.isActive ? Icons.sensors : Icons.sensors_off_outlined,
                color: _session.isActive ? const Color(0xFF0D6B5E) : const Color(0xFF8896AB),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.schedule.courseName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),
              const SizedBox(height: 2),
              Text('${widget.schedule.section}  ·  ${widget.schedule.venue}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8896AB))),
            ])),
            _StatusBadge(status: _session.status),
          ])),
          const SizedBox(height: 12),

          // Attendance code
          if (_session.isActive) ...[
            _Card(child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Attendance Code',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF8896AB), letterSpacing: 0.5)),
                TextButton.icon(
                  onPressed: _generateCode,
                  icon: const Icon(Icons.refresh_outlined, size: 14),
                  label: const Text('New Code', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1A3A6B),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ..._session.attendanceCode.split('').map((c) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 42, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDDE2EC)),
                  ),
                  child: Center(child: Text(c,
                    style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A3A6B), letterSpacing: 0,
                    ))),
                )),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF8896AB)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _session.attendanceCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Code copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ));
                  },
                ),
              ]),
              const SizedBox(height: 4),
              Text('Share this code with your students',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ])),
            const SizedBox(height: 12),
          ],

          // Metrics
          Row(children: [
            _MetricTile(
              label: 'Enrolled',
              value: _enrolledCount != null ? '$_enrolledCount' : '—',
              icon: Icons.people_outline,
              color: const Color(0xFF1A3A6B),
            ),
            const SizedBox(width: 10),
            _MetricTile(
              label: 'Present',
              value: '$presentCount',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF0D6B5E),
            ),
            const SizedBox(width: 10),
            _MetricTile(
              label: 'Rate',
              value: total > 0 ? '${(pct * 100).toStringAsFixed(0)}%' : '—',
              icon: Icons.show_chart,
              color: pct >= 0.8
                  ? const Color(0xFF0D6B5E)
                  : pct >= 0.5
                    ? const Color(0xFFC47F00)
                    : const Color(0xFFB22222),
            ),
          ]),
          const SizedBox(height: 12),

          // Poll error banner
          if (_pollError)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off_outlined, size: 16, color: Color(0xFFC47F00)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Live updates paused',
                  style: TextStyle(fontSize: 13, color: Color(0xFFC47F00), fontWeight: FontWeight.w500))),
                TextButton(
                  onPressed: _loadLiveSubmissions,
                  child: const Text('Retry', style: TextStyle(fontSize: 12, color: Color(0xFFC47F00))),
                ),
              ]),
            ),

          // Action buttons
          if (_session.isActive) ...[
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LecturerAttendanceRecord(session: _session, schedule: widget.schedule))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A3A6B),
                  side: const BorderSide(color: Color(0xFF1A3A6B)),
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('View Records', style: TextStyle(fontSize: 13)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: _closing ? null : _closeSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  minimumSize: const Size(0, 44),
                ),
                child: _closing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Close Session', style: TextStyle(fontSize: 13)),
              )),
            ]),
          ] else ...[
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => LecturerAttendanceRecord(session: _session, schedule: widget.schedule))),
              child: const Text('View Attendance Record'),
            )),
          ],
          const SizedBox(height: 20),

          // Submissions header
          Row(children: [
            const Text('Submissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F2449))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECF2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_submissions.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A6B82))),
            ),
            const SizedBox(width: 8),
            if (_session.isActive && !_pollError)
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(color: Color(0xFF0D6B5E), shape: BoxShape.circle),
              ),
          ]),
          const SizedBox(height: 10),

          _submissions.isEmpty
            ? const _Card(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Column(children: [
                  Icon(Icons.hourglass_empty_outlined, size: 36, color: Color(0xFFB0BAD0)),
                  SizedBox(height: 10),
                  Text('Awaiting submissions',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748))),
                  SizedBox(height: 4),
                  Text('Students will appear here once they submit',
                    style: TextStyle(color: Color(0xFF8896AB), fontSize: 12)),
                ])),
              ))
            : _Card(child: Column(
                children: _submissions.asMap().entries.map((e) {
                  final sub = e.value;
                  final isLast = e.key == _submissions.length - 1;
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE8F5F2),
                          child: Text((sub.studentName ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D6B5E))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sub.studentName ?? '—',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F2449))),
                          Text('${sub.studentMatric ?? ''}  ·  ${sub.submittedAt.length >= 16 ? sub.submittedAt.substring(11, 16) : ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
                        ])),
                        _StatusPill(status: sub.attendanceStatus),
                      ]),
                    ),
                    if (!isLast) const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F7)),
                  ]);
                }).toList(),
              )),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: child,
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8896AB))),
      ]),
    ));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5F2) : const Color(0xFFF0F2F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isActive) ...[
          const Icon(Icons.circle, size: 7, color: Color(0xFF0D6B5E)),
          const SizedBox(width: 5),
        ],
        Text(isActive ? 'Active' : 'Closed',
          style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF0D6B5E) : const Color(0xFF8896AB),
          )),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPresent = status == 'present';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPresent ? const Color(0xFFE8F5F2) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPresent ? 'Present' : 'Rejected',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: isPresent ? const Color(0xFF0D6B5E) : const Color(0xFFD32F2F),
        ),
      ),
    );
  }
}
