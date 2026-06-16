import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/app_controller.dart';
import '../../models/attendance_session.dart';
import '../../models/class_schedule.dart';

/// Lets the student submit attendance for a class with an active session,
/// by entering the attendance code given by the lecturer and capturing GPS.
class StudentAttendanceSubmitPage extends StatefulWidget {
  const StudentAttendanceSubmitPage({
    super.key,
    required this.controller,
    required this.schedule,
  });

  final AppController controller;
  final ClassScheduleModel schedule;

  @override
  State<StudentAttendanceSubmitPage> createState() => _StudentAttendanceSubmitPageState();
}

class _StudentAttendanceSubmitPageState extends State<StudentAttendanceSubmitPage> {
  final _codeController = TextEditingController();

  bool _isLoadingSession = true;
  bool _isSubmitting = false;
  bool _isAcquiringLocation = false;
  String? _loadError;
  String? _submitError;

  AttendanceSessionModel? _session;

  @override
  void initState() {
    super.initState();
    loadActiveSession(widget.schedule.scheduleId);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// SAMS-PACK-412: loadActiveSession(schedule_id)
  /// Retrieves the currently active attendance session for the given schedule.
  /// Called on page open so the form knows whether the session is still active
  /// and whether the student has already submitted.
  /// Returns: AttendanceSession — stored in [_session], null if none active.
  Future<void> loadActiveSession(int scheduleId) async {
    setState(() {
      _isLoadingSession = true;
      _loadError = null;
    });
    try {
      final session = await widget.controller.apiService.getActiveAttendanceSession(
        token: widget.controller.token!,
        scheduleId: scheduleId,
      );
      if (!mounted) return;
      setState(() => _session = session);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingSession = false);
    }
  }

  /// SAMS-PACK-412: validateAttendanceCode(attendance_code)
  /// Checks whether the student has entered an attendance code before submitting.
  /// Sets [_submitError] and returns false if the field is empty.
  /// Returns: Boolean — true if code is non-empty, false if blank.
  bool validateAttendanceCode(String attendanceCode) {
    if (attendanceCode.isEmpty) {
      setState(() => _submitError = 'Attendance code is required.');
      return false;
    }
    return true;
  }

  /// SAMS-PACK-412: requestGPSLocation()
  /// Requests the student's current GPS coordinates from the device.
  /// Checks location permission and service status before acquiring.
  /// Sets [_submitError] if permission is denied or location is unavailable.
  /// Returns: Location (Position) — the student's current GPS fix, or null on failure.
  Future<Position?> requestGPSLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _submitError = 'Location permission is required to mark attendance.');
        return null;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _submitError = 'Please enable location services on your device.');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _submitError = 'Unable to get your current location. Please try again.');
      return null;
    }
  }

  /// SAMS-PACK-412: submitAttendance(attendance_code, gps_latitude, gps_longitude)
  /// Submits the student's attendance code and GPS location to the backend.
  /// Step 1 [A3]: validates the code is non-empty via validateAttendanceCode().
  /// Steps 7–8: captures GPS automatically via requestGPSLocation().
  /// Steps 5–12: backend verifies code, campus boundary, and duplicate submission.
  /// On success calls displaySubmissionStatus() with the result message.
  /// Returns: Boolean — true if submission was accepted, false otherwise.
  Future<void> submitAttendance(String attendanceCode, double gpsLatitude, double gpsLongitude) async {
    final message = await widget.controller.apiService.submitClassAttendance(
      token: widget.controller.token!,
      scheduleId: widget.schedule.scheduleId,
      attendanceCode: attendanceCode,
      latitude: gpsLatitude,
      longitude: gpsLongitude,
    );
    if (!mounted) return;
    displaySubmissionStatus('success', message);
    Navigator.of(context).pop(true);
  }

  /// SAMS-PACK-412: displaySubmissionStatus(status, message)
  /// Displays a success or error message to the student after submission.
  /// 'success' shows a snackbar and pops the page.
  /// 'error' sets [_submitError] so the inline error text is shown on the form.
  /// Returns: void
  void displaySubmissionStatus(String status, String message) {
    if (status == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      setState(() => _submitError = message);
    }
  }

  /// Orchestrates the full submit flow: validate → GPS → submit → display status.
  Future<void> _onSubmitTapped() async {
    final code = _codeController.text.trim();

    // validateAttendanceCode() — step 1
    if (!validateAttendanceCode(code)) return;

    setState(() {
      _isSubmitting = true;
      _isAcquiringLocation = true;
      _submitError = null;
    });

    try {
      // requestGPSLocation() — steps 7–8
      final position = await requestGPSLocation();
      if (mounted) { setState(() => _isAcquiringLocation = false); }
      if (position == null) return;

      // submitAttendance() — steps 5–12
      await submitAttendance(code, position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;
      displaySubmissionStatus('error', e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() {
        _isSubmitting = false;
        _isAcquiringLocation = false;
      });
    }
  }

  /// SAMS-PACK-412: render()
  /// Renders the attendance submission form — class info card, session status
  /// banners, attendance code input, GPS status indicator, and submit button.
  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Mark Attendance',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingSession
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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

                  if (_loadError != null)
                    _MessageBanner(message: _loadError!, color: const Color(0xFFFF3B30))
                  else if (_session == null || !_session!.isActive)
                    const _MessageBanner(
                      message: 'Attendance session has ended.',
                      color: Color(0xFF8A96A8),
                    )
                  else if (_session!.alreadySubmitted)
                    const _MessageBanner(
                      message: 'You have already submitted your attendance for this session.',
                      color: Color(0xFF22C55E),
                    )
                  else
                    _buildForm(),
                ],
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Code',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
          decoration: InputDecoration(
            hintText: 'Enter code from lecturer',
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),

        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Text(_submitError!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
        ],

        // SAMS-PACK-412: displaySubmissionStatus() — "Verifying your current location" during GPS capture.
        if (_isAcquiringLocation) ...[
          const SizedBox(height: 12),
          Row(
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E6BFF)),
              ),
              SizedBox(width: 10),
              Text(
                'Verifying your current location...',
                style: TextStyle(color: Color(0xFF2E6BFF), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _onSubmitTapped,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E6BFF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Submit Attendance',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
