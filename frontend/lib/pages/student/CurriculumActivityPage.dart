import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';
import '../../models/app_user.dart';
import '../../utils/restriction_checker.dart';
import 'fees/manage_fees_dashboard_page.dart';

// ── Time-window helpers ───────────────────────────────────────────────────────

DateTime _parseSlotDateTime(String date, String time12h) {
  final d = date.split('-');
  final parts = time12h.trim().split(RegExp(r'[:\s]'));
  // parts: ['8','00','AM'] or ['10','30','PM']
  var hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  final period = parts[2].toUpperCase();
  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;
  return DateTime(int.parse(d[0]), int.parse(d[1]), int.parse(d[2]), hour, minute);
}

bool _isSlotActive(String date, String time) {
  try {
    final slotDate = DateTime.parse(date);
    final now      = DateTime.now();
    if (slotDate.year  != now.year  ||
        slotDate.month != now.month ||
        slotDate.day   != now.day) {
      return false;
    }

    final halves = time.split(' - ');
    if (halves.length != 2) {
      return true; // date matches, can't parse time → show anyway
    }
    final start = _parseSlotDateTime(date, halves[0]);
    final end   = _parseSlotDateTime(date, halves[1]);
    // Strictly within the activity time window — no grace period.
    return !now.isBefore(start) && !now.isAfter(end);
  } catch (_) {
    return false;
  }
}

// Returns true only after the slot's end time has passed (or date is past).
bool _isSlotEnded(String date, String time) {
  try {
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final slotDay = DateTime.parse(date);
    final slotDate = DateTime(slotDay.year, slotDay.month, slotDay.day);

    if (slotDate.isBefore(today)) return true;
    if (slotDate.isAfter(today)) return false;

    // Same day — ended only after end time has passed.
    final halves = time.split(' - ');
    if (halves.length != 2) return false;
    final end = _parseSlotDateTime(date, halves[1]);
    return now.isAfter(end);
  } catch (_) {
    return false;
  }
}

// ── Attend data (returned by _AttendDialog) ───────────────────────────────────

class _AttendData {
  _AttendData({required this.code, required this.photo});
  final String code;
  final XFile  photo;
}

// ── GPS helpers ───────────────────────────────────────────────────────────────

Future<Position?> _getLocation() async {
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    return null;
  }
}

Future<String?> _reverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=16',
    );
    final response = await http.get(uri, headers: {'User-Agent': 'SAMS-App/1.0'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['display_name'] as String?;
    }
    return null;
  } catch (_) {
    return null;
  }
}

// ── OSM tile-based map image for PDF ─────────────────────────────────────────

int _tileX(double lon, int zoom) =>
    ((lon + 180) / 360 * pow(2, zoom)).floor();

int _tileY(double lat, int zoom) {
  final r = lat * pi / 180;
  return ((1 - log(tan(r) + 1 / cos(r)) / pi) / 2 * pow(2, zoom)).floor();
}

Future<ui.Image?> _fetchOsmTile(int zoom, int x, int y) async {
  try {
    final response = await http
        .get(Uri.parse('https://tile.openstreetmap.org/$zoom/$x/$y.png'),
            headers: {'User-Agent': 'SAMS-App/1.0'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> _fetchMapImage(double lat, double lon) async {
  try {
    const zoom       = 16;
    const tileSize   = 256;
    const gridRadius = 1; // 3×3 tiles
    const gridDim    = 2 * gridRadius + 1;
    const totalPx    = tileSize * gridDim; // 768

    final cx = _tileX(lon, zoom);
    final cy = _tileY(lat, zoom);
    final n  = pow(2, zoom).toDouble();

    // Pixel position of the GPS point within the 3×3 stitched image
    final latR   = lat * pi / 180;
    final pinX   = ((lon + 180) / 360 * n - (cx - gridRadius)) * tileSize;
    final pinY   = ((1 - log(tan(latR) + 1 / cos(latR)) / pi) / 2 * n -
                    (cy - gridRadius)) * tileSize;

    // Fetch all 9 tiles in parallel
    final futures = <Future<ui.Image?>>[];
    for (int dy = -gridRadius; dy <= gridRadius; dy++) {
      for (int dx = -gridRadius; dx <= gridRadius; dx++) {
        futures.add(_fetchOsmTile(zoom, cx + dx, cy + dy));
      }
    }
    final tiles = await Future.wait(futures);

    // Stitch tiles onto canvas
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalPx.toDouble(), totalPx.toDouble()),
      Paint()..color = const Color(0xFFE8E8E8),
    );

    for (int i = 0; i < tiles.length; i++) {
      final tile = tiles[i];
      if (tile == null) continue;
      final dx = (i % gridDim) * tileSize.toDouble();
      final dy = (i ~/ gridDim) * tileSize.toDouble();
      canvas.drawImage(tile, Offset(dx, dy), Paint());
    }

    // Draw red pin at GPS location
    final pin = Offset(pinX, pinY);
    canvas.drawCircle(pin.translate(0, 2), 13, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(pin, 13, Paint()..color = const Color(0xFFFF3B30));
    canvas.drawCircle(pin, 5,  Paint()..color = Colors.white);

    final picture  = recorder.endRecording();
    final image    = await picture.toImage(totalPx, totalPx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}


// ── PDF receipt generator ─────────────────────────────────────────────────────

String _formatTimestamp(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}/${p(dt.month)}/${dt.year}, ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
}

pw.Widget _pdfLabelValue(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

Future<Uint8List> _generateReceiptPdf({
  required ActivityRegistration registration,
  required AppUser user,
  required String receiptId,
  required String receiptHash,
  required DateTime timestamp,
  required Uint8List photoBytes,
  required double? latitude,
  required double? longitude,
  required String? address,
}) async {
  Uint8List? mapBytes;
  if (latitude != null && longitude != null) {
    mapBytes = await _fetchMapImage(latitude, longitude);
  }

  // Load all images async BEFORE building the page (build callback is sync)
  final photoImg = await flutterImageProvider(MemoryImage(photoBytes));
  pw.ImageProvider? mapImg;
  if (mapBytes != null) {
    mapImg = await flutterImageProvider(MemoryImage(mapBytes));
  }

  final headerColor = PdfColor.fromHex('#1E5BFF');
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: pw.BoxDecoration(
              color: headerColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Attendance Receipt',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('SA Management System – UMPSA',
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Receipt meta ─────────────────────────────────────────────────────
          _pdfLabelValue('Receipt ID', receiptId),
          _pdfLabelValue('Timestamp', _formatTimestamp(timestamp)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // ── Student info ─────────────────────────────────────────────────────
          pw.Text('Student Information',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfLabelValue('Full Name', user.name),
          _pdfLabelValue('Matric No.', user.studentId ?? '-'),
          _pdfLabelValue('Program', user.course ?? '-'),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // ── Activity info ─────────────────────────────────────────────────────
          pw.Text('Activity Information',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfLabelValue('Activity', registration.activity.name),
          _pdfLabelValue('Code', registration.activity.code),
          _pdfLabelValue('Date', _formatDate(registration.slot.date)),
          _pdfLabelValue('Time', registration.slot.time),
          _pdfLabelValue('CATS', '2 Cats'),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),

          // ── Attendance proof ──────────────────────────────────────────────────
          pw.Text('Attendance Proof',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (address != null) _pdfLabelValue('Address', address),
          if (latitude != null)
            _pdfLabelValue('GPS',
                '${latitude.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'),
          pw.SizedBox(height: 12),

          // ── Selfie photo (left) + map (right, larger) ────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Selfie Photo',
                      style: pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Image(photoImg, width: 120, height: 120,
                      fit: pw.BoxFit.cover),
                ],
              ),
              if (mapImg != null) ...[
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Location Map',
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Image(mapImg, height: 200, fit: pw.BoxFit.cover),
                    ],
                  ),
                ),
              ],
            ],
          ),

          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 4),
          pw.Text(
            'This receipt was generated by the SA Management System. '
            'Receipt ID: $receiptId.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main embedded widget
// ═══════════════════════════════════════════════════════════════════════════════

class StudentCurriculumContent extends StatefulWidget {
  const StudentCurriculumContent({
    super.key,
    required this.controller,
    required this.onBookNow,
  });

  final AppController controller;
  final void Function(Set<int> registeredActivityIds) onBookNow;

  @override
  State<StudentCurriculumContent> createState() => _StudentCurriculumContentState();
}

class _StudentCurriculumContentState extends State<StudentCurriculumContent> {
  List<ActivityRegistration> _registrations = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh every 30 s so Attend button visibility updates automatically
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final regs = await widget.controller.apiService
          .getStudentRegistrations(token: widget.controller.token!);
      if (!mounted) return;
      setState(() => _registrations = regs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Attend flow ───────────────────────────────────────────────────────────

  Future<void> _attendActivity(ActivityRegistration reg) async {
    // 1. Attend dialog
    final attendData = await showDialog<_AttendData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AttendDialog(
        activityName: reg.activity.name,
        slotTime: reg.slot.time,
      ),
    );
    if (attendData == null || !mounted) return;

    // 2. Loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // 3. GPS (silent, optional)
      final pos     = await _getLocation();
      final address = pos != null
          ? await _reverseGeocode(pos.latitude, pos.longitude)
          : null;

      // 4. Read photo bytes for receipt
      final photoBytes = await attendData.photo.readAsBytes();

      // 5. API call
      final result = await widget.controller.apiService.submitAttendance(
        token:          widget.controller.token!,
        slotId:         reg.slot.id,
        attendanceCode: attendData.code,
        photoBytes:     photoBytes,
        photoName:      attendData.photo.name,
        latitude:       pos?.latitude,
        longitude:      pos?.longitude,
        address:        address,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      // 6. Receipt modal
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReceiptModal(
          registration: reg,
          receiptId:    result.receiptId,
          receiptHash:  result.receiptHash,
          timestamp:    DateTime.now(),
          photoBytes:   photoBytes,
          user:         widget.controller.currentUser!,
          latitude:     pos?.latitude,
          longitude:    pos?.longitude,
          address:      address,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Claim credit flow ─────────────────────────────────────────────────────

  Future<void> _claimCredit(ActivityRegistration reg) async {
    final result = await showDialog<PlatformFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClaimCreditDialog(activityName: reg.activity.name),
    );
    if (result == null || !mounted) return;

    try {
      final updated = await widget.controller.apiService.claimWithProof(
        token:          widget.controller.token!,
        registrationId: reg.id,
        fileBytes:      result.bytes!,
        fileName:       result.name,
      );
      if (!mounted) return;
      setState(() {
        final idx = _registrations.indexWhere((r) => r.id == reg.id);
        if (idx != -1) _registrations[idx] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim submitted successfully!'),
          backgroundColor: Color(0xFF0EAF4B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cancelClaim(ActivityRegistration reg) async {
    try {
      final updated = await widget.controller.apiService.cancelClaim(
        token:          widget.controller.token!,
        registrationId: reg.id,
      );
      if (!mounted) return;
      setState(() {
        final idx = _registrations.indexWhere((r) => r.id == reg.id);
        if (idx != -1) _registrations[idx] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _cancelRegistration(ActivityRegistration reg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: Text('Remove registration for "${reg.activity.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Remove',
                style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await widget.controller.apiService.cancelRegistration(
        token:          widget.controller.token!,
        registrationId: reg.id,
      );
      if (!mounted) return;
      setState(() => _registrations.removeWhere((r) => r.id == reg.id));
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFFF3B30)),
    );
  }

  Future<void> _openBooking() async {
    final restricted = await checkAndShowRestriction(
      context: context,
      controller: widget.controller,
      onPayNow: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManageFeesDashboardPage(controller: widget.controller),
      )),
    );
    if (restricted) return;
    widget.onBookNow(_registrations.map((r) => r.activity.id).toSet());
  }

  int get _claimedCount => _registrations.where((r) => r.isClaimed).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Curriculum Activity',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
              SizedBox(height: 2),
              Text(
                'Track and claim your activity credits',
                style: TextStyle(fontSize: 13, color: Color(0xFF5B6B86)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        children: [
                          _BookNowCard(onTap: _openBooking),
                          const SizedBox(height: 14),
                          if (_registrations.isEmpty)
                            const _EmptyRegistrations()
                          else
                            ..._registrations.map(
                              (reg) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: _RegistrationCard(
                                  registration: reg,
                                  onAttend: () => _attendActivity(reg),
                                  onClaimCredit: () =>
                                      _claimCredit(reg),
                                  onCancelClaim: () =>
                                      _cancelClaim(reg),
                                  onCancelRegistration: () =>
                                      _cancelRegistration(reg),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _TotalCatsCard(claimedCount: _claimedCount),
        ),
      ],
    );
  }
}

// ── Book Now card ─────────────────────────────────────────────────────────────

class _BookNowCard extends StatelessWidget {
  const _BookNowCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x120D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFD3FF), width: 2),
            ),
            child: const Icon(Icons.play_circle_outline,
                color: Color(0xFF2E6BFF), size: 36),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Book Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E6BFF),
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF2E6BFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Registration card ─────────────────────────────────────────────────────────

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.registration,
    required this.onAttend,
    required this.onClaimCredit,
    required this.onCancelClaim,
    required this.onCancelRegistration,
  });

  final ActivityRegistration registration;
  final VoidCallback onAttend;
  final VoidCallback onClaimCredit;
  final VoidCallback onCancelClaim;
  final VoidCallback onCancelRegistration;

  @override
  Widget build(BuildContext context) {
    final reg      = registration;
    final slot     = reg.slot;
    final activity = reg.activity;
    final active   = _isSlotActive(slot.date, slot.time);
    final ended    = _isSlotEnded(slot.date, slot.time);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x120D1B2A), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(activity.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
              ),
              const SizedBox(width: 8),
              if (active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Ongoing',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6BFF))),
                )
              else
                _StatusBadge(status: reg.claimStatus),
            ],
          ),
          const SizedBox(height: 4),
          Text('Code: ${activity.code}',
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
          const SizedBox(height: 10),

          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: Color(0xFF5B6B86)),
            const SizedBox(width: 6),
            Text(_formatDate(slot.date),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time_outlined,
                size: 15, color: Color(0xFF5B6B86)),
            const SizedBox(width: 6),
            Text(slot.time,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF374151))),
          ]),

          if (activity.whatsappLink != null &&
              activity.whatsappLink!.isNotEmpty) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(activity.whatsappLink!);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('WhatsApp Group',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E6BFF),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF2E6BFF),
                  )),
            ),
          ],

          const SizedBox(height: 14),

          // ── Action buttons ───────────────────────────────────────────────
          // Attend: only during the active time window and not yet claimed
          if (active && reg.isNotClaimed) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAttend,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAF4B),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.how_to_reg_outlined,
                    size: 18, color: Colors.white),
                label: const Text('Attend',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ] else if (!active && reg.isNotClaimed) ...[
            Row(children: [
              if (ended) ...[
                Expanded(
                  child: FilledButton(
                    onPressed: onClaimCredit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6BFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Claim Credit',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton(
                onPressed: onCancelRegistration,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Icon(Icons.delete_outline, size: 20),
              ),
            ]),
          ] else if (reg.isPending) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCancelClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD4960A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel Claim',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'claimed'  => ('Claimed',     const Color(0xFFE7F9EE), const Color(0xFF0EAF4B)),
      'pending'  => ('Pending',     const Color(0xFFFFF5D8), const Color(0xFFD4960A)),
      'rejected' => ('Rejected',    const Color(0xFFFFEDEE), const Color(0xFFFF4D4F)),
      _          => ('Not Claimed', const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ── Total CATs card ───────────────────────────────────────────────────────────

class _TotalCatsCard extends StatelessWidget {
  const _TotalCatsCard({required this.claimedCount});
  final int claimedCount;

  @override
  Widget build(BuildContext context) {
    final cats = claimedCount * 2;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EAF4B), Color(0xFF08903D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Claimed Cats',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('$cats Cats',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined,
                color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyRegistrations extends StatelessWidget {
  const _EmptyRegistrations();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 52, color: Color(0xFFB0BEC5)),
          SizedBox(height: 12),
          Text('No activities registered yet',
              style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF5B6B86),
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Tap Book Now to join an activity',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A96A8))),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: Color(0xFFB0BEC5)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5B6B86))),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Attend dialog ─────────────────────────────────────────────────────────────

class _AttendDialog extends StatefulWidget {
  const _AttendDialog(
      {required this.activityName, required this.slotTime});
  final String activityName;
  final String slotTime;

  @override
  State<_AttendDialog> createState() => _AttendDialogState();
}

class _AttendDialogState extends State<_AttendDialog> {
  final _codeCtrl = TextEditingController();
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo  = await picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 85,
      maxWidth:     1280,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _photo = photo;
        _photoBytes = bytes;
      });
    }
  }

  void _submit() {
    setState(() => _codeError = null);

    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Please enter the attendance code.');
      return;
    }
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo as proof of attendance.'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    Navigator.of(context).pop(_AttendData(code: code, photo: _photo!));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Submit Attendance',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(widget.activityName,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2E6BFF),
                    fontWeight: FontWeight.w600)),
            Text(widget.slotTime,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF8A96A8))),
            const SizedBox(height: 20),

            // Attendance Code
            const Text('Attendance Code *',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter the code given at the event',
                hintStyle: const TextStyle(
                    color: Color(0xFFB0BAC9), fontSize: 13),
                errorText: _codeError,
                filled: true,
                fillColor: const Color(0xFFF8FAFD),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFD6E0F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFD6E0F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF1E5BFF), width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),

            // Take Photo
            const Text('Take Photo *',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),

            if (_photo == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side:
                        const BorderSide(color: Color(0xFF2E6BFF)),
                    foregroundColor: const Color(0xFF2E6BFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Open Camera',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _photoBytes!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retake Photo'),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6BFF),
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Receipt modal ─────────────────────────────────────────────────────────────

class _ReceiptModal extends StatefulWidget {
  const _ReceiptModal({
    required this.registration,
    required this.receiptId,
    required this.receiptHash,
    required this.timestamp,
    required this.photoBytes,
    required this.user,
    this.latitude,
    this.longitude,
    this.address,
  });

  final ActivityRegistration registration;
  final String    receiptId;
  final String    receiptHash;
  final DateTime  timestamp;
  final Uint8List photoBytes;
  final AppUser   user;
  final double?   latitude;
  final double?   longitude;
  final String?   address;

  @override
  State<_ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<_ReceiptModal> {
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _generateReceiptPdf(
        registration: widget.registration,
        user:         widget.user,
        receiptId:    widget.receiptId,
        receiptHash:  widget.receiptHash,
        timestamp:    widget.timestamp,
        photoBytes:   widget.photoBytes,
        latitude:     widget.latitude,
        longitude:    widget.longitude,
        address:      widget.address,
      );
      await Printing.sharePdf(
        bytes:    bytes,
        filename: '${widget.receiptId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF error: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = widget.registration;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E5BFF), Color(0xFF1544D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Attendance Receipt',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Warning banner
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF5D8),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFD4960A), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Download now! This receipt will not be saved in the app. '
                    'You will need this PDF to claim your credit later.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92600A),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable receipt content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt ID
                  _receiptRow('Receipt ID', widget.receiptId,
                      highlight: true),
                  _receiptRow('Timestamp',
                      _formatTimestamp(widget.timestamp)),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Student info
                  _sectionTitle('Student Information'),
                  _receiptRow('Name', widget.user.name),
                  _receiptRow(
                      'Matric No.', widget.user.studentId ?? '-'),
                  _receiptRow(
                      'Program', widget.user.course ?? '-'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Activity info
                  _sectionTitle('Activity Information'),
                  _receiptRow('Activity', reg.activity.name),
                  _receiptRow('Code', reg.activity.code),
                  _receiptRow('Date', _formatDate(reg.slot.date)),
                  _receiptRow('Time', reg.slot.time),
                  _receiptRow('CATS', '2 Cats'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Proof
                  _sectionTitle('Attendance Proof'),
                  if (widget.latitude != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 160,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                                widget.latitude!, widget.longitude!),
                            initialZoom: 16,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.sams.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                      widget.latitude!, widget.longitude!),
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Color(0xFFFF3B30),
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (widget.address != null)
                      Text(
                        widget.address!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF5B6B86)),
                      ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.my_location_outlined,
                          size: 12, color: Color(0xFFB0BAC9)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.latitude!.toStringAsFixed(5)}, '
                        '${widget.longitude!.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFB0BAC9)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 4),

                  // Photo preview
                  const Text('Selfie Photo',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF8A96A8))),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(widget.photoBytes,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _downloading ? null : _downloadPdf,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5BFF),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.download_outlined,
                            color: Colors.white),
                    label: Text(
                        _downloading
                            ? 'Generating PDF…'
                            : 'Download Receipt',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
      );

  Widget _receiptRow(String label, String value,
      {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8A96A8))),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: highlight
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: highlight
                          ? const Color(0xFF1E5BFF)
                          : const Color(0xFF111827),
                      letterSpacing: highlight ? 0.5 : 0)),
            ),
          ],
        ),
      );
}

// ── Claim Credit dialog (PDF only) ────────────────────────────────────────────

class _ClaimCreditDialog extends StatefulWidget {
  const _ClaimCreditDialog({required this.activityName});
  final String activityName;

  @override
  State<_ClaimCreditDialog> createState() => _ClaimCreditDialogState();
}

class _ClaimCreditDialogState extends State<_ClaimCreditDialog> {
  PlatformFile? _pickedFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Claim Credit',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 6),
            const Text(
              'Upload the digital receipt PDF you downloaded after attendance.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
            const SizedBox(height: 18),

            const Text('Upload Digital Receipt (PDF) *',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: _pickFile,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        border:
                            Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Choose File',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF374151))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedFile?.name ?? 'No file chosen',
                        style: TextStyle(
                          fontSize: 13,
                          color: _pickedFile != null
                              ? const Color(0xFF111827)
                              : const Color(0xFF9CA3AF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Accepted: PDF only • Max 5 MB',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),

            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _pickedFile == null
                      ? null
                      : () =>
                          Navigator.of(context).pop(_pickedFile),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6BFF),
                    disabledBackgroundColor:
                        const Color(0xFFCDD9FF),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Date formatter ────────────────────────────────────────────────────────────

String _formatDate(String dateStr) {
  final parts = dateStr.split('-');
  final dt    = DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  const months   = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  return '${weekdays[dt.weekday]}, ${months[dt.month]} ${dt.day}, ${dt.year}';
}
