import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// api_service.dart — SAMS (api_service)
/// Handles all HTTP communication between Flutter and Laravel backend.
class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api'; // Chrome/web uses local Laravel server
  static const _storage = FlutterSecureStorage();

  // ── Token management ───────────────────────────────────────────────────────
  static Future<String?> getToken() async => _storage.read(key: 'token');
  static Future<void> saveToken(String token) => _storage.write(key: 'token', value: token);
  static Future<void> clearToken() => _storage.delete(key: 'token');

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> logout() async {
    final res = await http.post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders());
    await clearToken();
    return _decode(res);
  }

  // ── Lecturer: Schedules ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLecturerSchedules() async {
    final res = await http.get(Uri.parse('$baseUrl/lecturer/schedules'), headers: await _authHeaders());
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getTodaySchedules() async {
    final res = await http.get(Uri.parse('$baseUrl/lecturer/schedules/today'), headers: await _authHeaders());
    return _decode(res);
  }

  // FIX: Enrolled count for active session screen
  static Future<Map<String, dynamic>> getEnrolledCount(int scheduleId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/lecturer/schedules/$scheduleId/enrolled-count'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ── Lecturer: Session ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> startSession(int scheduleId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/lecturer/sessions/start'),
      headers: await _authHeaders(),
      body: jsonEncode({'schedule_id': scheduleId}),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateCode(int sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/lecturer/sessions/$sessionId/generate-code'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getLiveSubmissions(int sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/lecturer/sessions/$sessionId/live'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> closeSession(int sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/lecturer/sessions/$sessionId/close'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getAttendanceRecord(int sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/lecturer/sessions/$sessionId/record'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ── Lecturer: Reports ──────────────────────────────────────────────────────

  // FIX: Now properly uses the dedicated /report/filter endpoint
  static Future<Map<String, dynamic>> getReportFilter() async {
    final res = await http.get(
      Uri.parse('$baseUrl/lecturer/report/filter'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  static Future<Map<String, dynamic>> generateReport(int scheduleId, String sessionDate) async {
    final res = await http.get(
      Uri.parse('$baseUrl/lecturer/report?schedule_id=$scheduleId&session_date=$sessionDate'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // FIX: SAMS-REQ-414 — Download report as CSV bytes
  static Future<http.Response> downloadReport(int scheduleId, String sessionDate) async {
    final headers = await _authHeaders();
    // Remove Content-Type for GET; Accept CSV so server returns file
    headers['Accept'] = 'text/csv,application/octet-stream';
    return http.get(
      Uri.parse('$baseUrl/lecturer/report/download?schedule_id=$scheduleId&session_date=$sessionDate'),
      headers: headers,
    );
  }

  // ── Student: Schedules & Sessions ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getEnrolledSchedules() async {
    final res = await http.get(Uri.parse('$baseUrl/student/schedules'), headers: await _authHeaders());
    return _decode(res);
  }

  static Future<Map<String, dynamic>> getActiveSession(int scheduleId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/student/schedules/$scheduleId/active-session'),
      headers: await _authHeaders(),
    );
    return _decode(res);
  }

  // ── Student: Submit Attendance ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> submitAttendance({
    required int scheduleId,
    required String attendanceCode,
    required double gpsLatitude,
    required double gpsLongitude,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/student/attendance/submit'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'schedule_id':     scheduleId,
        'attendance_code': attendanceCode,
        'gps_latitude':    gpsLatitude,
        'gps_longitude':   gpsLongitude,
      }),
    );
    return _decode(res);
  }

  // ── Internal helper ────────────────────────────────────────────────────────
  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map<String, dynamic>) {
        return {'status': res.statusCode, ...decoded};
      }

      return {
        'status': res.statusCode,
        'success': false,
        'message': decoded.toString(),
      };
    } catch (e) {
      return {
        'status': res.statusCode,
        'success': false,
        'message': 'Server returned invalid response (${res.statusCode}): ${res.body}',
      };
    }
  }
}
