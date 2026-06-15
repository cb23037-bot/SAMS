import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../models/activity_registration.dart';
import '../../models/app_user.dart';

// ════════════════════════════════════════════════════════════════════════════
// This file implements the student-facing "Curriculum Activity" page — the
// screen where a student tracks the activities they registered for, marks
// attendance (with photo + GPS proof), downloads a PDF receipt, and submits
// that receipt to claim CATs (Co-Curriculum Activity Transcript) credits.
//
// Top-level structure:
//   - Time-window / GPS / PDF helper functions (module-level, no state)
//   - StudentCurriculumContent: the main embedded page widget
//   - Supporting display widgets (cards, badges, empty/error states)
//   - _AttendDialog / _ReceiptModal / _ClaimCreditDialog: the attendance flow
//   - _formatDate: shared date formatting helper
// ════════════════════════════════════════════════════════════════════════════

// ── Time-window helpers ───────────────────────────────────────────────────────

/// Combines a `yyyy-MM-dd` [date] string with a 12-hour [time12h] string
/// (e.g. "8:00 AM") into a single [DateTime].
///
/// Used to compare slot start/end times against the current time when
/// deciding whether an activity slot is currently active or has ended.
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

/// True only if [date] is today AND the current time falls within the
/// slot's start/end time range parsed from [time] (format "start - end").
///
/// Used to decide whether to show the "Attend" button on a registration card —
/// students can only mark attendance during the exact activity time window
/// (no grace period before or after).
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

/// Returns true only after the slot's end time has passed (or its date is
/// entirely in the past).
///
/// Used to decide whether to show the "Claim Credit" button — claiming is
/// only allowed once the activity has fully ended.
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

/// Simple value object holding the result of [_AttendDialog]: the attendance
/// code entered by the student and the selfie photo taken as proof.
class _AttendData {
  _AttendData({required this.code, required this.photo});
  final String code;
  final XFile  photo;
}

// ── GPS helpers ───────────────────────────────────────────────────────────────

/// Attempts to get the device's current GPS position.
///
/// Returns `null` (instead of throwing) if location permission is denied or
/// any error occurs — GPS proof is optional, so attendance submission must
/// still succeed without it.
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

/// Converts GPS coordinates into a human-readable address using the free
/// OpenStreetMap Nominatim reverse-geocoding API.
///
/// Returns `null` on any failure (network error, non-200 response, etc.) —
/// the address is purely informational and shown on the receipt, so it must
/// not block the attendance flow if it fails.
Future<String?> _reverseGeocode(double lat, double lon) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=16',
    );
    final response = await http
        .get(uri, headers: {'User-Agent': 'SAMS-App/1.0'})
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
//
// The PDF receipt cannot embed an interactive map widget, so we build a
// static map image instead: fetch a 3×3 grid of OpenStreetMap tiles around
// the GPS point, stitch them into one canvas, and draw a pin at the exact
// coordinates. The result is rendered as a PNG and embedded in the PDF.

/// Converts a longitude to an OSM tile X index at the given [zoom] level.
/// Standard "slippy map" tile math — see OSM wiki for the formula.
int _tileX(double lon, int zoom) =>
    ((lon + 180) / 360 * pow(2, zoom)).floor();

/// Converts a latitude to an OSM tile Y index at the given [zoom] level.
/// Standard "slippy map" tile math — see OSM wiki for the formula.
int _tileY(double lat, int zoom) {
  final r = lat * pi / 180;
  return ((1 - log(tan(r) + 1 / cos(r)) / pi) / 2 * pow(2, zoom)).floor();
}

/// Downloads a single OSM tile image at ([zoom], [x], [y]) as raw PNG bytes.
/// Returns `null` on any network failure so the map is simply omitted
/// from the receipt rather than crashing PDF generation.
Future<Uint8List?> _fetchOsmTile(int zoom, int x, int y) async {
  try {
    final resp = await http
        .get(Uri.parse('https://tile.openstreetmap.org/$zoom/$x/$y.png'),
            headers: {'User-Agent': 'SAMS-App/1.0'})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  } catch (_) {
    return null;
  }
}

/// Builds a static map PNG centered on ([lat], [lon]) with a red pin marker,
/// for embedding in the PDF receipt. Fetches a 3×3 grid of OSM tiles, stitches
/// them into one 768×768 canvas, and draws the pin at the precise GPS pixel
/// position. Returns `null` on any failure (map is then omitted from the PDF).
///
/// Built with `package:image` (pure Dart, renderer-agnostic) rather than
/// `dart:ui`'s Canvas/Picture APIs, which don't reliably rasterize on Flutter Web.
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
    final futures = <Future<Uint8List?>>[];
    for (int dy = -gridRadius; dy <= gridRadius; dy++) {
      for (int dx = -gridRadius; dx <= gridRadius; dx++) {
        futures.add(_fetchOsmTile(zoom, cx + dx, cy + dy));
      }
    }
    final tiles = await Future.wait(futures);

    // Stitch tiles onto canvas
    final canvas = img.Image(width: totalPx, height: totalPx);
    img.fill(canvas, color: img.ColorRgb8(0xE8, 0xE8, 0xE8));

    for (int i = 0; i < tiles.length; i++) {
      final bytes = tiles[i];
      if (bytes == null) continue;
      final tile = img.decodePng(bytes);
      if (tile == null) continue;
      img.compositeImage(canvas, tile,
          dstX: (i % gridDim) * tileSize, dstY: (i ~/ gridDim) * tileSize);
    }

    // Draw red pin at GPS location
    final pinXi = pinX.round();
    final pinYi = pinY.round();
    img.fillCircle(canvas,
        x: pinXi, y: pinYi + 2, radius: 13, color: img.ColorRgba8(0, 0, 0, 0x55));
    img.fillCircle(canvas,
        x: pinXi, y: pinYi, radius: 13, color: img.ColorRgb8(0xFF, 0x3B, 0x30));
    img.fillCircle(canvas,
        x: pinXi, y: pinYi, radius: 5, color: img.ColorRgb8(0xFF, 0xFF, 0xFF));

    return img.encodePng(canvas);
  } catch (_) {
    return null;
  }
}


// ── PDF receipt generator ─────────────────────────────────────────────────────

/// Formats [dt] as `dd/MM/yyyy, HH:mm:ss` for display on receipts.
String _formatTimestamp(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}/${p(dt.month)}/${dt.year}, ${p(dt.hour)}:${p(dt.minute)}:${p(dt.second)}';
}

/// Builds a single "label: value" row used throughout the PDF receipt layout.
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

/// Generates the downloadable PDF "Attendance Receipt" for [registration],
/// embedding the student's selfie [photoBytes], a static map of the GPS
/// location (if available), and the [receiptId]/[receiptHash] returned by
/// the attendance submission API.
///
/// This PDF is what the student later uploads to [_ClaimCreditDialog] to
/// claim CATs credits, so it must contain everything Pusat Adab needs to
/// verify the attendance (timestamp, location, photo, activity details).
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

/// The student's "Curriculum Activity" tab content.
///
/// Shows a "Book Now" entry point, the list of activities the student has
/// registered for (each as a [_RegistrationCard]), and a summary card of
/// total claimed CATs. This widget is embedded inside the student's main
/// scaffold/navigation shell (it is not its own [Scaffold]).
class StudentCurriculumContent extends StatefulWidget {
  const StudentCurriculumContent({
    super.key,
    required this.controller,
    required this.onBookNow,
    this.highlightRegistrationId,
  });

  /// Shared app state — used here to access [AppController.apiService] and
  /// the auth [AppController.token] for all network calls.
  final AppController controller;

  /// Called when the student taps "Book Now". Receives the set of activity
  /// IDs the student is already registered for, so the booking page can
  /// hide/disable activities that would create a duplicate registration.
  final void Function(Set<int> registeredActivityIds) onBookNow;

  /// Registration to scroll to and highlight on load — set when the student
  /// taps a notification to jump straight to the related activity.
  final int? highlightRegistrationId;

  @override
  State<StudentCurriculumContent> createState() => _StudentCurriculumContentState();
}

class _StudentCurriculumContentState extends State<StudentCurriculumContent> {
  /// All of the student's activity registrations, as returned by the API.
  /// This is the single source of truth for the list rendered below.
  List<ActivityRegistration> _registrations = [];

  /// True while [_load] is fetching registrations from the server.
  bool _loading = true;

  /// Error message from the last failed [_load] call, or null if the last
  /// load succeeded. Shown via [_ErrorView] with a retry button.
  String? _error;

  /// Periodic timer that triggers a rebuild every 30 seconds so the
  /// "Attend" button appears/disappears automatically as slot time windows
  /// open and close, without requiring the user to manually refresh.
  Timer? _timer;

  /// Registration ID to scroll to and visually highlight on first load
  /// (copied from [StudentCurriculumContent.highlightRegistrationId]).
  /// Cleared automatically a couple seconds after scrolling into view.
  int? _highlightRegId;

  /// Per-registration [GlobalKey]s so [_scrollToHighlight] can locate and
  /// scroll to the highlighted card's position in the list.
  final Map<int, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _highlightRegId = widget.highlightRegistrationId;
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

  /// Fetches the student's registrations from the backend and refreshes
  /// the list. If [_highlightRegId] is set, schedules a scroll-to-highlight
  /// once the new list has been laid out.
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final regs = await widget.controller.apiService
          .getStudentRegistrations(token: widget.controller.token!);
      if (!mounted) return;
      setState(() => _registrations = regs);
      if (_highlightRegId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Scrolls the list so the card matching [_highlightRegId] is visible,
  /// then clears the highlight after a short delay so it doesn't stay
  /// outlined forever.
  void _scrollToHighlight() {
    final id = _highlightRegId;
    if (id == null) return;
    final ctx = _cardKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.1);
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightRegId = null);
    });
  }

  // ── Attend flow ───────────────────────────────────────────────────────────

  /// Runs the full "mark attendance" flow for [reg]:
  ///
  /// 1. Show [_AttendDialog] to collect the attendance code + selfie photo.
  /// 2. Show a blocking loading overlay while submitting.
  /// 3. Try to capture GPS coordinates and reverse-geocode an address
  ///    (best-effort — failures are silently ignored).
  /// 4. Read the photo bytes (needed to embed in the receipt PDF).
  /// 5. Call the attendance API to record the attendance and get back a
  ///    receipt ID/hash.
  /// 6. Close the loading overlay and show [_ReceiptModal] so the student
  ///    can download the PDF receipt (required later for claiming credit).
  ///
  /// Any error during submission closes the loading overlay and shows a
  /// snackbar via [_showError].
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

  /// Shows [_ClaimCreditDialog] for [reg] to pick a PDF receipt, uploads it
  /// via [ApiService.claimWithProof], and updates the local registration's
  /// claim status to "pending" on success.
  ///
  /// Updates the in-memory [_registrations] list in place (rather than
  /// re-fetching) so the UI reflects the new status immediately.
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

  /// Cancels a pending credit claim for [reg], reverting its status back to
  /// "not claimed" so the student can re-attend/re-submit if needed.
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

  /// Removes the student's registration for [reg] entirely (not a claim
  /// cancellation — this unregisters them from the activity slot).
  /// Shows a confirmation dialog first since this action is irreversible.
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

  /// Shows a red error snackbar with [message].
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFFF3B30)),
    );
  }

  /// Navigates to the booking page, passing along the IDs of activities the
  /// student is already registered for so they can't double-book.
  void _openBooking() {
    widget.onBookNow(_registrations.map((r) => r.activity.id).toSet());
  }

  /// Number of registrations whose claim has been approved by Pusat Adab.
  /// Used by [_TotalCatsCard] to compute total CATs earned (2 per claim).
  int get _claimedCount => _registrations.where((r) => r.isClaimed).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page header ─────────────────────────────────────────────────
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
        // ── Body: loading / error / registration list ──────────────────
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
                            // Each card gets a GlobalKey so it can be scrolled
                            // into view when highlighted (see _scrollToHighlight).
                            ..._registrations.map(
                              (reg) => Padding(
                                key: _cardKeys.putIfAbsent(reg.id, () => GlobalKey()),
                                padding:
                                    const EdgeInsets.only(bottom: 14),
                                child: _RegistrationCard(
                                  registration: reg,
                                  highlighted: reg.id == _highlightRegId,
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
        // ── Footer: total CATs summary ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: _TotalCatsCard(claimedCount: _claimedCount),
        ),
      ],
    );
  }
}

// ── Book Now card ─────────────────────────────────────────────────────────────

/// Static call-to-action card at the top of the list that navigates the
/// student to the activity booking page when tapped.
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

/// Card showing one activity registration: name, code, schedule, status
/// badge, rejection reason (if any), WhatsApp link, and the action button(s)
/// appropriate to the registration's current state (Attend / Claim Credit /
/// Cancel Claim / Cancel Registration).
///
/// The visible action button is determined entirely by [_isSlotActive],
/// [_isSlotEnded] and [ActivityRegistration.claimStatus] — see the
/// "Action buttons" section in [build] below.
class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.registration,
    required this.onAttend,
    required this.onClaimCredit,
    required this.onCancelClaim,
    required this.onCancelRegistration,
    this.highlighted = false,
  });

  final ActivityRegistration registration;

  /// Called when the student taps "Attend" (only shown while the slot is
  /// currently active and the claim hasn't been started).
  final VoidCallback onAttend;

  /// Called when the student taps "Claim Credit" (only shown once the slot
  /// has ended and the claim hasn't been started).
  final VoidCallback onClaimCredit;

  /// Called when the student taps "Cancel Claim" (only shown while a claim
  /// is pending review).
  final VoidCallback onCancelClaim;

  /// Called when the student taps the delete icon to remove this
  /// registration entirely (only shown when no claim has been made yet).
  final VoidCallback onCancelRegistration;

  /// True if this card should be visually outlined — set briefly when the
  /// student navigates here from a notification (see
  /// [_StudentCurriculumContentState._scrollToHighlight]).
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final reg      = registration;
    final slot     = reg.slot;
    final activity = reg.activity;
    final active   = _isSlotActive(slot.date, slot.time);
    final ended    = _isSlotEnded(slot.date, slot.time);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? const Color(0xFF2E6BFF) : Colors.transparent,
          width: 2,
        ),
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

          if (reg.isRejected &&
              reg.rejectionReason != null &&
              reg.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD9DB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reason for rejection',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF3B30),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reg.rejectionReason!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                  ),
                ],
              ),
            ),
          ],

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

/// Small pill showing the registration's claim status ("Claimed", "Pending",
/// "Rejected", or "Not Claimed") with status-appropriate colors.
/// Maps directly to [ActivityRegistration.claimStatus] values.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // Pick label/background/foreground colors based on claim status.
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

/// Green summary footer card showing the student's total claimed CATs
/// credits (2 CATs per approved claim, per [claimedCount]).
class _TotalCatsCard extends StatelessWidget {
  const _TotalCatsCard({required this.claimedCount});
  final int claimedCount;

  @override
  Widget build(BuildContext context) {
    // Each claimed registration is worth a fixed 2 CATs.
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

/// Placeholder shown in the registration list when the student has not
/// registered for any activities yet.
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

/// Shown in place of the registration list when [_StudentCurriculumContentState._load]
/// fails (e.g. network error). Displays [message] and a "Retry" button that
/// calls [onRetry] to attempt loading again.
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

/// Step 1 of the attendance flow: prompts the student to enter the
/// attendance code announced at the activity and take a selfie photo as
/// proof. Pops with an [_AttendData] result, or `null` if dismissed.
class _AttendDialog extends StatefulWidget {
  const _AttendDialog(
      {required this.activityName, required this.slotTime});
  final String activityName;
  final String slotTime;

  @override
  State<_AttendDialog> createState() => _AttendDialogState();
}

class _AttendDialogState extends State<_AttendDialog> {
  /// Controller for the attendance code text field.
  final _codeCtrl = TextEditingController();

  /// The selfie photo taken via [_takePhoto], or null until captured.
  XFile? _photo;

  /// Validation error shown under the code field, or null if valid.
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Opens the device camera to capture a proof-of-attendance selfie.
  /// Image is downscaled (max width 1280, quality 85) to keep upload/PDF
  /// size reasonable.
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo  = await picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 85,
      maxWidth:     1280,
    );
    if (photo != null) setState(() => _photo = photo);
  }

  /// Validates the attendance code and photo, then closes the dialog
  /// returning an [_AttendData]. Shows inline/snackbar errors if either
  /// the code is empty or no photo has been taken.
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
                    child: kIsWeb
                        ? Image.network(
                            _photo!.path,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_photo!.path),
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

/// Step 2 of the attendance flow: shown immediately after attendance is
/// successfully submitted. Displays a summary of the receipt (ID, timestamp,
/// student/activity info, GPS map, selfie) and lets the student download the
/// PDF version via [_generateReceiptPdf].
///
/// IMPORTANT: this receipt is NOT stored by the app — the warning banner
/// tells the student to download it now, because the downloaded PDF is what
/// they must upload later in [_ClaimCreditDialog] to claim CATs credit.
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
  /// True while the PDF is being generated/shared, used to disable the
  /// download button and show a spinner.
  bool _downloading = false;

  /// Generates the receipt PDF via [_generateReceiptPdf] and opens the
  /// platform share/save sheet via [Printing.sharePdf].
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

  /// Renders a bold section heading (e.g. "Student Information") within the
  /// receipt's scrollable content.
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
      );

  /// Renders a "label: value" row in the receipt. When [highlight] is true
  /// (used for the Receipt ID), the value is styled in bold blue to draw
  /// attention to it.
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

/// Step 3 of the attendance flow: lets the student pick the PDF receipt
/// (downloaded earlier from [_ReceiptModal]) and submit it to claim CATs
/// credit. Pops with the selected [PlatformFile], or `null` if cancelled.
///
/// Submission of the picked file is handled by the caller
/// ([_StudentCurriculumContentState._claimCredit]) via
/// [ApiService.claimWithProof] — this dialog only handles file selection.
class _ClaimCreditDialog extends StatefulWidget {
  const _ClaimCreditDialog({required this.activityName});
  final String activityName;

  @override
  State<_ClaimCreditDialog> createState() => _ClaimCreditDialogState();
}

class _ClaimCreditDialogState extends State<_ClaimCreditDialog> {
  /// The PDF file chosen via [_pickFile], or null until one is selected.
  /// The "Submit" button stays disabled until this is non-null.
  PlatformFile? _pickedFile;

  /// Opens the system file picker restricted to PDF files.
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

/// Converts a `yyyy-MM-dd` date string into a friendly format like
/// "Monday, June 15, 2026" for display on cards and receipts.
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
