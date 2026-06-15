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
  bool _isLocating = false;
  String? _loadError;
  String? _submitError;

  AttendanceSessionModel? _session;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoadingSession = true;
      _loadError = null;
    });
    try {
      final session = await widget.controller.apiService.getActiveAttendanceSession(
        token: widget.controller.token!,
        scheduleId: widget.schedule.scheduleId,
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

  Future<void> _getLocation() async {
    setState(() {
      _isLocating = true;
      _submitError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _submitError = 'Location permission is required to mark attendance.');
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _submitError = 'Please enable location services on your device.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _position = position);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = 'Unable to get your current location. Please try again.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _submitError = 'Please enter the attendance code given by your lecturer.');
      return;
    }
    if (_position == null) {
      setState(() => _submitError = 'Please capture your current location first.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final message = await widget.controller.apiService.submitClassAttendance(
        token: widget.controller.token!,
        scheduleId: widget.schedule.scheduleId,
        attendanceCode: code,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
                      message: 'There is no active attendance session for this class right now.',
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

        const SizedBox(height: 20),

        const Text(
          'Your Location',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 8),
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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFF2E6BFF), shape: BoxShape.circle),
                child: const Icon(Icons.my_location, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _position == null
                      ? 'Location not captured yet'
                      : 'Lat: ${_position!.latitude.toStringAsFixed(6)}, Lng: ${_position!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isLocating ? null : _getLocation,
                child: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Get Location'),
              ),
            ],
          ),
        ),

        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Text(_submitError!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
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
