// student_attendance_form.dart — Boundary Screen
// Requirement ID : SAMS-PACK-412
// Responsibility : Allows the student to submit attendance by entering the
//                  lecturer's attendance code and providing their GPS location
//                  for on-campus verification.
//
// Attributes:
//   attendanceCode  String
//   gpsLocation     GPS
//   session         AttendanceSession
//   schedule        ClassSchedule
//
// Methods:
//   render()                   — Renders the attendance submission form.
//   loadActiveSession()        — Loads the active session for the selected class.
//   validateAttendanceCode()   — Validates the attendance code entered by the student.
//   requestGPSLocation()       — Requests GPS location from the device.
//   submitAttendance()         — Submits attendance with code and GPS coordinates.
//   displaySubmissionStatus()  — Displays success or error result to the student.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class StudentAttendanceForm extends StatefulWidget {
  final UserModel user;
  final ClassScheduleModel schedule;
  const StudentAttendanceForm({super.key, required this.user, required this.schedule});

  @override
  State<StudentAttendanceForm> createState() => _StudentAttendanceFormState();
}

class _StudentAttendanceFormState extends State<StudentAttendanceForm> {
  final _codeCtrl = TextEditingController();
  // UI state machine: idle | verifying_gps | submitting | success | error
  String _status = 'idle';
  String _errorMessage = '';
  double? _gpsLat;
  double? _gpsLng;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  // requestGPSLocation() — bool
  // SAMS-PACK-412
  Future<bool> _getLocation() async {
    setState(() { _status = 'verifying_gps'; _errorMessage = ''; });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'error';
        _errorMessage = 'Location services are disabled. Please enable GPS and try again.';
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _status = 'error';
        _errorMessage = 'Location permission denied. Please allow location access in your browser and try again.';
      });
      return false;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _gpsLat = pos.latitude;
      _gpsLng = pos.longitude;
      return true;
    } on TimeoutException {
      setState(() {
        _status = 'error';
        _errorMessage = 'GPS timed out. Make sure location is enabled and try again.';
      });
      return false;
    } catch (e) {
      setState(() {
        _status = 'error';
        _errorMessage = 'Unable to get location. Allow location access in your browser and try again.';
      });
      return false;
    }
  }

  // submitAttendance() — void
  // SAMS-PACK-412
  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter the attendance code.');
      return;
    }
    final gpsOk = await _getLocation();
    if (!gpsOk) return;

    setState(() { _status = 'submitting'; _errorMessage = ''; });
    try {
      final res = await ApiService.submitAttendance(
        scheduleId:     widget.schedule.scheduleId,
        attendanceCode: _codeCtrl.text.trim().toUpperCase(),
        gpsLatitude:    _gpsLat!,
        gpsLongitude:   _gpsLng!,
      );
      if (res['status'] == 201) {
        // displaySubmissionStatus(success) — SAMS-PACK-412
        setState(() => _status = 'success');
      } else {
        // displaySubmissionStatus(error) — SAMS-PACK-412
        setState(() {
          _status = 'error';
          _errorMessage = res['message'] ?? 'Submission failed.';
        });
      }
    } catch (_) {
      setState(() {
        _status = 'error';
        _errorMessage = 'Could not connect to server. Please try again.';
      });
    }
  }

  // render() — void  (SAMS-PACK-412)
  @override
  Widget build(BuildContext context) {
    // displaySubmissionStatus(success) — SAMS-PACK-412
    if (_status == 'success') {
      return _SuccessScreen(schedule: widget.schedule);
    }

    final activeSession = widget.schedule.activeSession;
    final busy = _status == 'verifying_gps' || _status == 'submitting';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Submit Attendance',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Class info card — Module 1 style
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EDF6)),
              boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E5BFF).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined, color: Color(0xFF1E5BFF), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.schedule.courseName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text('${widget.schedule.courseCode}  ·  ${widget.schedule.section}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
                const SizedBox(height: 2),
                Text('${widget.schedule.startTime} – ${widget.schedule.endTime}  ·  ${widget.schedule.venue}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
              ])),
            ]),
          ),
          const SizedBox(height: 10),

          // Session status banner — loadActiveSession() result
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: activeSession != null
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08)
                  : const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activeSession != null
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : const Color(0xFFE8EDF6),
              ),
            ),
            child: Row(children: [
              Icon(
                activeSession != null ? Icons.sensors : Icons.sensors_off_outlined,
                size: 16,
                color: activeSession != null ? const Color(0xFF22C55E) : const Color(0xFF5B6B86),
              ),
              const SizedBox(width: 8),
              Text(
                activeSession != null
                    ? 'Attendance session is active'
                    : 'No active session for this class',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: activeSession != null ? const Color(0xFF22C55E) : const Color(0xFF5B6B86),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (activeSession != null) ...[
            // Code input card — validateAttendanceCode() — SAMS-PACK-412
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EDF6)),
                boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Attendance Code',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                const Text('Enter the 6-character code shown by your lecturer',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 14,
                    color: Color(0xFF1E5BFF),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '······',
                    hintStyle: const TextStyle(
                      fontSize: 30, letterSpacing: 14, color: Color(0xFFE8EDF6),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFD),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                  onChanged: (_) => setState(() => _errorMessage = ''),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Verification steps card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EDF6)),
                boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Verification steps',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 10),
                ...[
                  ('Verify attendance code', Icons.key_outlined),
                  ('Request your GPS location', Icons.gps_fixed_outlined),
                  ('Confirm you are on campus', Icons.location_on_outlined),
                  ('Check for duplicate submissions', Icons.verified_outlined),
                ].asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5BFF).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF1E5BFF)))),
                    ),
                    const SizedBox(width: 10),
                    Icon(e.value.item2, size: 14, color: const Color(0xFF5B6B86)),
                    const SizedBox(width: 6),
                    Text(e.value.item1,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),

            // Progress indicator — verifying_gps / submitting
            if (_status == 'verifying_gps' || _status == 'submitting')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E5BFF).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E5BFF).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1E5BFF))),
                  const SizedBox(width: 14),
                  Text(
                    _status == 'verifying_gps'
                        ? 'Retrieving GPS location…'
                        : 'Submitting attendance…',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111827),
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),

            // Error banner — displaySubmissionStatus(error) — SAMS-PACK-412
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage,
                    style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13, height: 1.4))),
                ]),
              ),

            // Submit button — submitAttendance() trigger — SAMS-PACK-412
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Submit Attendance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

          ] else ...[
            // No active session — loadActiveSession() returned null
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EDF6)),
                boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Column(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.schedule_outlined, size: 28, color: Color(0xFF5B6B86)),
                ),
                const SizedBox(height: 14),
                const Text('No Active Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                const SizedBox(height: 6),
                const Text(
                  'Your lecturer has not started an attendance session for this class yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E5BFF),
                    side: const BorderSide(color: Color(0xFF1E5BFF)),
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Classes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

extension _Tuple2<A, B> on (A, B) {
  A get item1 => $1;
  B get item2 => $2;
}

// ─── Success screen ───────────────────────────────────────────────────────────
// displaySubmissionStatus(success) — SAMS-PACK-412
// Shown when StudentAttendanceController returns HTTP 201.
class _SuccessScreen extends StatelessWidget {
  final ClassScheduleModel schedule;
  const _SuccessScreen({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Green gradient success card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text('Attendance Submitted',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Text(schedule.courseName,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center),
                  Text('${schedule.courseCode}  ·  ${schedule.section}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Your attendance has been recorded successfully.',
                      style: TextStyle(fontSize: 13, color: Colors.white,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                    ..pop()
                    ..pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Classes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
