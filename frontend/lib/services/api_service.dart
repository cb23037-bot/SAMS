import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/activity.dart';
import '../models/activity_registration.dart';
import '../models/activity_slot.dart';
import '../models/app_user.dart';

class ApiService {
  /// Called whenever any API request receives a 401 Unauthenticated response.
  /// Wire this up in AppController to auto-sign-out on stale tokens.
  static void Function()? onUnauthorized;

  // ── Shared request helper ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${_baseUrl()}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
        case 'POST':
          response = await http.post(uri, headers: headers, body: encodedBody);
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encodedBody);
        case 'DELETE':
          response = await http.delete(uri, headers: headers, body: encodedBody);
        default:
          throw Exception('Unsupported method: $method');
      }

      final raw = response.body;
      final json = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      if (response.statusCode == 401) onUnauthorized?.call();
      throw ApiException(_extractMessage(json), code: json['code'] as String?);
    } on http.ClientException catch (e) {
      throw ApiException('Unable to connect to the server. Make sure the backend is running. (${e.message})');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<LoginResponse> login({required String email, required String password}) async {
    final json = await _request(
      method: 'POST',
      path: '/login',
      body: {'email': email, 'password': password},
    );
    return LoginResponse(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Future<void> logout({required String token}) async {
    await _request(method: 'POST', path: '/logout', token: token);
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  Future<AppUser> updateProfile({
    required String token,
    required Map<String, dynamic> fields,
  }) async {
    final json = await _request(method: 'PUT', path: '/profile', token: token, body: fields);
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  // ── Curriculum Activities ──────────────────────────────────────────────────

  Future<List<Activity>> getActivities({required String token}) async {
    final json = await _request(method: 'GET', path: '/activities', token: token);
    return (json['activities'] as List<dynamic>)
        .map((a) => Activity.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<Activity> createActivity({
    required String token,
    required String name,
    required String location,
    String? code,
    String? whatsappLink,
    String? description,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/activities',
      token: token,
      body: {
        'name': name,
        'location': location,
        if (code != null && code.isNotEmpty) 'code': code,
        if (whatsappLink != null && whatsappLink.isNotEmpty) 'whatsapp_link': whatsappLink,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Activity.fromJson(json['activity'] as Map<String, dynamic>);
  }

  Future<Activity> updateActivity({
    required String token,
    required int id,
    required String name,
    required String code,
    required String location,
    String? whatsappLink,
    String? description,
  }) async {
    final json = await _request(
      method: 'PUT',
      path: '/activities/$id',
      token: token,
      body: {
        'name': name,
        'code': code,
        'location': location,
        'whatsapp_link': whatsappLink ?? '',
        'description': description ?? '',
      },
    );
    return Activity.fromJson(json['activity'] as Map<String, dynamic>);
  }

  Future<void> deleteActivity({required String token, required int id}) async {
    await _request(method: 'DELETE', path: '/activities/$id', token: token);
  }

  // ── Activity Slots ─────────────────────────────────────────────────────────

  Future<ActivitySlot> addSlot({
    required String token,
    required int activityId,
    required String date,
    required String time,
    required int capacity,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/activities/$activityId/slots',
      token: token,
      body: {'date': date, 'time': time, 'capacity': capacity},
    );
    return ActivitySlot.fromJson(json['slot'] as Map<String, dynamic>);
  }

  Future<void> deleteSlot({
    required String token,
    required int activityId,
    required int slotId,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/activities/$activityId/slots/$slotId',
      token: token,
    );
  }

  // ── Student Registrations ──────────────────────────────────────────────────

  Future<List<ActivityRegistration>> getStudentRegistrations({required String token}) async {
    final json = await _request(method: 'GET', path: '/student/registrations', token: token);
    return (json['registrations'] as List<dynamic>)
        .map((r) => ActivityRegistration.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<ActivityRegistration> registerSlot({
    required String token,
    required int slotId,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/student/registrations',
      token: token,
      body: {'slot_id': slotId},
    );
    return ActivityRegistration.fromJson(json['registration'] as Map<String, dynamic>);
  }

  Future<void> cancelRegistration({
    required String token,
    required int registrationId,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/student/registrations/$registrationId',
      token: token,
    );
  }

  /// Submits a credit claim with a proof document.
  /// [fileBytes] is the raw file content; [fileName] is used for MIME detection.
  Future<ActivityRegistration> claimWithProof({
    required String token,
    required int registrationId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${_baseUrl()}/student/registrations/$registrationId/claim');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('proof', fileBytes, filename: fileName));

    try {
      final streamed = await request.send();
      final raw = await streamed.stream.bytesToString();
      final json = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return ActivityRegistration.fromJson(json['registration'] as Map<String, dynamic>);
      }
      throw Exception(_extractMessage(json));
    } on http.ClientException catch (e) {
      throw Exception('Unable to connect to the server. (${e.message})');
    }
  }

  // ── Attendance Submission ──────────────────────────────────────────────────

  /// [photoBytes] is the raw image content read from the XFile.
  Future<AttendanceResult> submitAttendance({
    required String token,
    required int slotId,
    required String attendanceCode,
    required Uint8List photoBytes,
    required String photoName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final uri = Uri.parse('${_baseUrl()}/student/attendances');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['slot_id'] = '$slotId'
      ..fields['attendance_code'] = attendanceCode
      ..files.add(http.MultipartFile.fromBytes('photo', photoBytes, filename: photoName));

    if (latitude != null) request.fields['latitude'] = '$latitude';
    if (longitude != null) request.fields['longitude'] = '$longitude';
    if (address != null) request.fields['address'] = address;

    try {
      final streamed = await request.send();
      final raw = await streamed.stream.bytesToString();
      final json = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final sub = json['submission'] as Map<String, dynamic>;
        return AttendanceResult(
          receiptId: sub['receipt_id'] as String,
          receiptHash: sub['receipt_hash'] as String,
        );
      }
      throw Exception(_extractMessage(json));
    } on http.ClientException catch (e) {
      throw Exception('Unable to connect to the server. (${e.message})');
    }
  }

  Future<ActivityRegistration> cancelClaim({
    required String token,
    required int registrationId,
  }) async {
    final json = await _request(
      method: 'DELETE',
      path: '/student/registrations/$registrationId/claim',
      token: token,
    );
    return ActivityRegistration.fromJson(json['registration'] as Map<String, dynamic>);
  }

  // ── Student: Access State ─────────────────────────────────────────────────

  Future<bool> getStudentAccessOpen({required String token}) async {
    final json = await _request(method: 'GET', path: '/student/access', token: token);
    return (json['student_access'] as String) == 'open';
  }

  // ── Pusat Adab: Access Control ─────────────────────────────────────────────

  Future<bool> getAdabAccess({required String token}) async {
    final json = await getAdabAccessState(token: token);
    return (json['student_access'] as String) == 'open';
  }

  Future<Map<String, dynamic>> getAdabAccessState({required String token}) async {
    final json = await _request(method: 'GET', path: '/adab/access', token: token);
    return json;
  }

  Future<Map<String, dynamic>> setAdabAccessState({required String token, required bool open}) async {
    return _request(
      method: 'PUT',
      path: '/adab/access',
      token: token,
      body: {'status': open ? 'open' : 'closed'},
    );
  }

  Future<bool> setAdabAccess({required String token, required bool open}) async {
    final json = await setAdabAccessState(token: token, open: open);
    return (json['student_access'] as String) == 'open';
  }

  // ── Pusat Adab: Credit Claim Management ───────────────────────────────────

  Future<Map<String, dynamic>> getAdabNotifications({required String token}) async {
    return _request(method: 'GET', path: '/adab/notifications', token: token);
  }

  Future<Map<String, dynamic>> getClaimsOverview({required String token}) async {
    return _request(method: 'GET', path: '/adab/claims', token: token);
  }

  Future<Map<String, dynamic>> getActivityClaims({
    required String token,
    required int activityId,
  }) async {
    return _request(method: 'GET', path: '/adab/claims/$activityId', token: token);
  }

  Future<Map<String, dynamic>> approveClaim({
    required String token,
    required int registrationId,
    String? remarks,
  }) async {
    return _request(
      method: 'PUT',
      path: '/adab/claims/$registrationId/approve',
      token: token,
      body: {'remarks': remarks ?? ''},
    );
  }

  Future<Map<String, dynamic>> rejectClaim({
    required String token,
    required int registrationId,
    required String reason,
  }) async {
    return _request(
      method: 'PUT',
      path: '/adab/claims/$registrationId/reject',
      token: token,
      body: {'reason': reason},
    );
  }

  Future<Uint8List> downloadProof({
    required String token,
    required int registrationId,
  }) async {
    final uri = Uri.parse('${_baseUrl()}/adab/claims/$registrationId/proof');
    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': '*/*',
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      final json = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(_extractMessage(json));
    } on http.ClientException catch (e) {
      throw Exception('Unable to connect to the server. (${e.message})');
    }
  }

  // ── Fees: Student ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentFees({required String token}) async {
    return _request(method: 'GET', path: '/fees', token: token);
  }

  Future<Map<String, dynamic>> getFeeDetails({
    required String token,
    required int feeId,
  }) async {
    return _request(method: 'GET', path: '/fees/$feeId', token: token);
  }

  Future<Map<String, dynamic>> makePayment({
    required String token,
    required int feeId,
    required double amount,
    required String paymentMethod,
  }) async {
    return _request(
      method: 'POST',
      path: '/fees/$feeId/pay',
      token: token,
      body: {'amount': amount, 'payment_method': paymentMethod},
    );
  }

  Future<Map<String, dynamic>> getPaymentHistory({required String token}) async {
    return _request(method: 'GET', path: '/payments', token: token);
  }

  Future<Map<String, dynamic>> getReceipt({
    required String token,
    required int paymentId,
  }) async {
    return _request(method: 'GET', path: '/payments/$paymentId/receipt', token: token);
  }

  // ── Fees: Treasury ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTreasuryDashboard({required String token}) async {
    return _request(method: 'GET', path: '/treasury/dashboard', token: token);
  }

  Future<Map<String, dynamic>> getTreasuryStats({required String token}) async {
    return _request(method: 'GET', path: '/treasury/stats', token: token);
  }

  Future<Map<String, dynamic>> getFeeRecords({
    required String token,
    String? search,
    String? status,
  }) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (status != null && status.isNotEmpty) params.add('status=${Uri.encodeComponent(status)}');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return _request(method: 'GET', path: '/treasury/fees$query', token: token);
  }

  Future<Map<String, dynamic>> getFeeRecord({
    required String token,
    required int feeId,
  }) async {
    return _request(method: 'GET', path: '/treasury/fees/$feeId', token: token);
  }

  Future<Map<String, dynamic>> getUnpaidFees({required String token}) async {
    return _request(method: 'GET', path: '/treasury/unpaid', token: token);
  }

  Future<Map<String, dynamic>> updateFeeRecord({
    required String token,
    required int feeId,
    required Map<String, dynamic> fields,
  }) async {
    return _request(method: 'PUT', path: '/treasury/fees/$feeId', token: token, body: fields);
  }

  // ── Restriction ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRestrictionStatus({required String token}) async {
    return _request(method: 'GET', path: '/student/restriction-status', token: token);
  }

  Future<Map<String, dynamic>> getStudentSponsors({required String token}) async {
    return _request(method: 'GET', path: '/student/sponsors', token: token);
  }

  Future<Map<String, dynamic>> getStudentLedger({required String token}) async {
    return _request(method: 'GET', path: '/student/ledger', token: token);
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications({required String token}) async {
    return _request(method: 'GET', path: '/notifications', token: token);
  }

  Future<void> markNotificationRead({required String token, required int id}) async {
    await _request(method: 'PUT', path: '/notifications/$id/read', token: token);
  }

  Future<void> markAllNotificationsRead({required String token}) async {
    await _request(method: 'PUT', path: '/notifications/read-all', token: token);
  }

  // ── Receipt PDF download URL ───────────────────────────────────────────────

  String receiptDownloadUrl(int paymentId) =>
      '${_baseUrl()}/receipts/$paymentId/download';

  Future<void> applyRestriction({required String token, required int userId}) async {
    await _request(method: 'POST', path: '/treasury/restrict/$userId', token: token);
  }

  Future<void> liftRestriction({required String token, required int userId}) async {
    await _request(method: 'DELETE', path: '/treasury/restrict/$userId', token: token);
  }

  Future<Map<String, dynamic>> getTreasurySettings({required String token}) async {
    return _request(method: 'GET', path: '/treasury/settings', token: token);
  }

  Future<void> updateTreasurySettings({
    required String token,
    required Map<String, dynamic> settings,
  }) async {
    await _request(method: 'PUT', path: '/treasury/settings', token: token, body: settings);
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  String _baseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    // Android emulator reaches host via 10.0.2.2
    return 'http://10.0.2.2:8000/api';
  }

  String _extractMessage(Map<String, dynamic> json) {
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;
    final errors = json['errors'];
    if (errors is Map<String, dynamic>) {
      for (final entry in errors.values) {
        if (entry is List && entry.isNotEmpty) return entry.first.toString();
      }
    }
    return 'Request failed. Please try again.';
  }
}

// ── Response models ────────────────────────────────────────────────────────────

/// Carries an optional error [code] (e.g. DB_ERROR, GATEWAY_UNAVAILABLE)
/// so callers can branch on specific failure types.
class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class LoginResponse {
  const LoginResponse({required this.token, required this.user});
  final String token;
  final AppUser user;
}

class AttendanceResult {
  const AttendanceResult({required this.receiptId, required this.receiptHash});
  final String receiptId;
  final String receiptHash;
}
