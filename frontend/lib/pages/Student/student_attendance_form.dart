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
  // idle | verifying_gps | submitting | success | error
  String _status = 'idle';
  String _errorMessage = '';
  double? _gpsLat;
  double? _gpsLng;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<bool> _getLocation() async {
    setState(() { _status = 'verifying_gps'; _errorMessage = ''; });

    // Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'error';
        _errorMessage = 'Location services are disabled. Please enable GPS and try again.';
      });
      return false;
    }

    // Check / request permission (works on mobile; on web the browser handles this)
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
        setState(() => _status = 'success');
      } else {
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

  @override
  Widget build(BuildContext context) {
    if (_status == 'success') {
      return _SuccessScreen(schedule: widget.schedule);
    }

    final activeSession = widget.schedule.activeSession;
    final busy = _status == 'verifying_gps' || _status == 'submitting';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      appBar: AppBar(title: const Text('Submit Attendance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Class info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF2)),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined, color: Color(0xFF1A3A6B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.schedule.courseName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                      color: Color(0xFF0F2449))),
                const SizedBox(height: 2),
                Text('${widget.schedule.courseCode}  ·  ${widget.schedule.section}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF8896AB))),
                const SizedBox(height: 2),
                Text('${widget.schedule.startTime} – ${widget.schedule.endTime}  ·  ${widget.schedule.venue}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB0BAD0))),
              ])),
            ]),
          ),
          const SizedBox(height: 10),

          // Session status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: activeSession != null ? const Color(0xFFE8F5F2) : const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activeSession != null
                    ? const Color(0xFFB2DFDB)
                    : const Color(0xFFDDE2EC),
              ),
            ),
            child: Row(children: [
              Icon(
                activeSession != null
                    ? Icons.sensors
                    : Icons.sensors_off_outlined,
                size: 16,
                color: activeSession != null
                    ? const Color(0xFF0D6B5E)
                    : const Color(0xFF8896AB),
              ),
              const SizedBox(width: 8),
              Text(
                activeSession != null
                    ? 'Attendance session is active'
                    : 'No active session for this class',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: activeSession != null
                      ? const Color(0xFF0D6B5E)
                      : const Color(0xFF8896AB),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          if (activeSession != null) ...[
            // Code input card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECF2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Attendance Code',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748))),
                const SizedBox(height: 4),
                const Text('Enter the 6-character code shown by your lecturer',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8896AB))),
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
                    color: Color(0xFF1A3A6B),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '······',
                    hintStyle: const TextStyle(
                      fontSize: 30, letterSpacing: 14,
                      color: Color(0xFFDDE2EC),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1A3A6B), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onChanged: (_) => setState(() => _errorMessage = ''),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // Steps card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECF2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Verification steps',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748))),
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
                        color: const Color(0xFFEEF1F8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF1A3A6B)))),
                    ),
                    const SizedBox(width: 10),
                    Icon(e.value.item2, size: 14, color: const Color(0xFF8896AB)),
                    const SizedBox(width: 6),
                    Text(e.value.item1,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B82))),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),

            // Progress indicator
            if (_status == 'verifying_gps' || _status == 'submitting')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8ECF2)),
                ),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1A3A6B))),
                  const SizedBox(width: 14),
                  Text(
                    _status == 'verifying_gps'
                        ? 'Retrieving GPS location…'
                        : 'Submitting attendance…',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2D3748),
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),

            // Error message
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage,
                    style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13, height: 1.4))),
                ]),
              ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3A6B),
                ),
                child: const Text('Submit Attendance',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

          ] else ...[
            // No active session
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECF2)),
              ),
              child: Column(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.schedule_outlined,
                      size: 28, color: Color(0xFFB0BAD0)),
                ),
                const SizedBox(height: 14),
                const Text('No Active Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F2449))),
                const SizedBox(height: 6),
                const Text(
                  'Your lecturer has not started an attendance session for this class yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF8896AB), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A3A6B),
                    side: const BorderSide(color: Color(0xFF1A3A6B)),
                    minimumSize: const Size(160, 42),
                  ),
                  child: const Text('Back to Classes'),
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

class _SuccessScreen extends StatelessWidget {
  final ClassScheduleModel schedule;
  const _SuccessScreen({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6B5E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.check_rounded, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Attendance Submitted',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Color(0xFF0F2449), letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(schedule.courseName,
                style: const TextStyle(fontSize: 15, color: Color(0xFF5A6B82)),
                textAlign: TextAlign.center),
              Text('${schedule.courseCode}  ·  ${schedule.section}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8896AB))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Your attendance has been recorded successfully.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0D6B5E),
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                    ..pop()
                    ..pop(),
                  child: const Text('Back to Classes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
