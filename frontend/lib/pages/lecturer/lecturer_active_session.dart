import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../models/attendance_session.dart';
import '../../models/class_attendance_submission.dart';
import '../../models/class_schedule.dart';
import 'lecturer_attendance_record.dart';

/// SDD Flow:
/// Step 4  → Lecturer taps "Start Attendance Session"
/// Step 5  → System checks for existing active session [A1]
/// Step 6  → Session created (active), but NO code shown yet
/// Step 7  → Lecturer taps "Generate Attendance Code"
/// Step 8  → System generates random code
/// Step 9  → Code displayed to lecturer
/// Step 11 → Live submissions polled every 5s
/// Step 12 → Lecturer taps "Close Attendance Session"
/// Step 13 → Session status set to Closed; return to class list
/// Step 14 → Lecturer selects "View Attendance Record" explicitly from class list
class LecturerAttendanceSessionPage extends StatefulWidget {
  const LecturerAttendanceSessionPage({
    super.key,
    required this.controller,
    required this.schedule,
  });

  final AppController controller;
  final ClassScheduleModel schedule;

  @override
  State<LecturerAttendanceSessionPage> createState() => _LecturerAttendanceSessionPageState();
}

class _LecturerAttendanceSessionPageState extends State<LecturerAttendanceSessionPage> {
  Timer? _pollTimer;

  bool _isStarting = false;
  bool _isGenerating = false;
  bool _isRegenerating = false;
  bool _isClosing = false;
  String? _error;

  LiveAttendanceModel? _live;

  /// True once the lecturer has clicked "Generate Attendance Code" at least once.
  bool _codeGenerated = false;

  /// Set when [A1] is detected — holds the existing session so the
  /// "Return to Active Session" button can load it directly.
  AttendanceSessionModel? _existingSession;

  @override
  void initState() {
    super.initState();
    final activeSession = widget.schedule.activeSession;
    if (activeSession != null && activeSession.isActive) {
      _existingSession = activeSession;
      _error = 'An attendance session is already active for this class.';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => loadLiveSubmissions());
  }

  /// SAMS-PACK-408: loadActiveSession(attendance_session_id)
  /// Loads the current active session details for this schedule.
  /// Called on page open [A1] and after starting a session.
  /// Returns: AttendanceSession — the active session, or null if none.
  Future<void> loadActiveSession(int attendanceSessionId) async {
    try {
      final live = await widget.controller.apiService.getLiveAttendance(
        token: widget.controller.token!,
        sessionId: attendanceSessionId,
      );
      if (!mounted) return;
      setState(() => _live = live);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// SAMS-PACK-408: loadLiveSubmissions(attendance_session_id)
  /// Retrieves the live list of student attendance submissions for the
  /// current session. Polled every 5 seconds while the session is active.
  /// Returns: List<AttendanceSubmission> — all submissions so far.
  Future<void> loadLiveSubmissions() async {
    final sessionId = _live?.session.attendanceSessionId ?? widget.schedule.activeSession?.attendanceSessionId;
    if (sessionId == null) return;
    await loadActiveSession(sessionId);
  }

  // Step 4–6: Start session; session is active but code is NOT shown yet.
  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      final result = await widget.controller.apiService.startAttendanceSession(
        token: widget.controller.token!,
        scheduleId: widget.schedule.scheduleId,
      );
      if (!mounted) return;

      // [A1] Active Session Already Exists
      if (result.alreadyActive) {
        if (!mounted) return;
        setState(() {
          _error = 'An attendance session is already active for this class.';
          _existingSession = result.session;
        });
        return;
      }

      setState(() {
        _live = LiveAttendanceModel(
          session: result.session,
          enrolledCount: widget.schedule.enrolledCount ?? 0,
          submittedCount: 0,
          submissions: const [],
        );
        _codeGenerated = false; // Wait for explicit "Generate Attendance Code" tap
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  /// SAMS-PACK-408: generateAttendanceCode(attendance_session_id)
  /// Requests the backend to generate a random attendance code for the session.
  /// Step 7–9: Lecturer explicitly generates the code; code is then displayed.
  /// Returns: String — the generated attendance code.
  Future<void> generateAttendanceCode(int attendanceSessionId) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });
    try {
      await widget.controller.apiService.generateAttendanceCode(
        token: widget.controller.token!,
        sessionId: attendanceSessionId,
      );
      await loadLiveSubmissions();
      if (!mounted) return;
      setState(() => _codeGenerated = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // [A1] Load the existing active session and go to the live view.
  Future<void> _returnToActiveSession() async {
    final session = _existingSession;
    if (session == null) return;
    setState(() {
      _error = null;
      _live = LiveAttendanceModel(
        session: session,
        enrolledCount: widget.schedule.enrolledCount ?? 0,
        submittedCount: 0,
        submissions: const [],
      );
      _codeGenerated = true;
      _existingSession = null;
    });
    _startPolling();
    await loadLiveSubmissions();
  }

  // Regenerate a new code while session is still active.
  Future<void> _regenerateCode() async {
    final sessionId = _live?.session.attendanceSessionId;
    if (sessionId == null) return;

    setState(() => _isRegenerating = true);
    try {
      await widget.controller.apiService.generateAttendanceCode(
        token: widget.controller.token!,
        sessionId: sessionId,
      );
      await loadLiveSubmissions();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  /// SAMS-PACK-408: closeAttendanceSession(attendance_session_id)
  /// Closes the active attendance session. Students can no longer submit after this.
  /// Step 12–13: Confirms with lecturer, closes session, returns session ID to
  /// the class list so the lecturer can view the attendance record (Step 14).
  /// Returns: Boolean — true if session was closed successfully.
  Future<void> closeAttendanceSession(int attendanceSessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Attendance Session'),
        content: const Text('Students will no longer be able to mark attendance for this session. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Close Session')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isClosing = true);
    try {
      await widget.controller.apiService.closeAttendanceSession(
        token: widget.controller.token!,
        sessionId: attendanceSessionId,
      );
      _pollTimer?.cancel();
      if (!mounted) return;
      // Return to class list with the closed session ID so the lecturer can
      // explicitly select "View Attendance Record" (Step 14).
      Navigator.of(context).pop(attendanceSessionId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  /// SAMS-PACK-408: render()
  /// Renders the active attendance session interface — shows the start card,
  /// generate code card, or live session view depending on state.
  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final live = _live;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: Text(
          schedule.courseCode,
          style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
        actions: [
          if (live != null && live.session.isActive)
            IconButton(
              tooltip: 'View Attendance Record',
              icon: const Icon(Icons.list_alt, color: Color(0xFF111827)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LecturerAttendanceRecordPage(
                    controller: widget.controller,
                    sessionId: live.session.attendanceSessionId,
                    schedule: schedule,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class info card
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
                    'Section ${schedule.section} • ${schedule.venue}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${schedule.day}, ${schedule.startTime} - ${schedule.endTime}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFF3B30))),
              ),
              const SizedBox(height: 16),
            ],

            if (live == null || !live.session.isActive)
              _buildStartCard()
            else if (!_codeGenerated)
              _buildGenerateCodeCard(live)
            else
              _buildActiveSession(live),
          ],
        ),
      ),
    );
  }

  // Step 4: No session yet — show "Start Attendance Session" button.
  Widget _buildStartCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active session for this class',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a session first, then generate an attendance code for your students.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isStarting ? null : _startSession,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6BFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isStarting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Start Attendance Session',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
          if (_existingSession != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _returnToActiveSession,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E6BFF),
                  side: const BorderSide(color: Color(0xFF2E6BFF)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Return to Active Session',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 7: Session started — show "Generate Attendance Code" button.
  Widget _buildGenerateCodeCard(LiveAttendanceModel live) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: Color(0xFF2E6BFF), shape: BoxShape.circle),
            child: const Icon(Icons.password, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Session Started',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate an attendance code and share it with your students.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isGenerating ? null : () => generateAttendanceCode(live.session.attendanceSessionId),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E6BFF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Generate Attendance Code',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isClosing ? null : () => closeAttendanceSession(live.session.attendanceSessionId),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close Session', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // Steps 9–13: Code is displayed; live submissions shown; close session button.
  Widget _buildActiveSession(LiveAttendanceModel live) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance code card (Step 9)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Attendance Code',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5B6B86)),
              ),
              const SizedBox(height: 8),
              Text(
                live.session.attendanceCode,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E6BFF),
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isRegenerating ? null : _regenerateCode,
                icon: _isRegenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Generate New Code'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Live count card (Step 11)
        Row(
          children: [
            Expanded(
              child: _CountCard(
                label: 'Enrolled',
                value: live.enrolledCount.toString(),
                color: const Color(0xFF3B82F6),
                icon: Icons.groups_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CountCard(
                label: 'Submitted',
                value: live.submittedCount.toString(),
                color: const Color(0xFF22C55E),
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        const Text(
          'Live Submissions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),

        if (live.submissions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: const Center(
              child: Text('No submissions yet.', style: TextStyle(color: Color(0xFF5B6B86))),
            ),
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
              children: live.submissions.asMap().entries.map((entry) {
                final isLast = entry.key == live.submissions.length - 1;
                final submission = entry.value;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        submission.isPresent ? Icons.check_circle : Icons.cancel,
                        color: submission.isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30),
                      ),
                      title: Text(submission.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(submission.matricNo),
                      trailing: Text(
                        submission.isPresent ? 'Present' : 'Rejected',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: submission.isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
            // Remove this misplaced line or ensure it is part of a valid widget.
        const SizedBox(height: 24),

        // Step 12: Close Attendance Session button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isClosing ? null : () => closeAttendanceSession(_live!.session.attendanceSessionId),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
              side: const BorderSide(color: Color(0xFFFFCDD2)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isClosing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Close Session', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
            ],
          ),
        ],
      ),
    );
  }
}
