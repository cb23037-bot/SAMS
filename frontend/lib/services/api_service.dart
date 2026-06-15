import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/activity.dart';
import '../models/activity_registration.dart';
import '../models/activity_slot.dart';
import '../models/app_user.dart';
import '../models/attendance_report.dart';
import '../models/attendance_session.dart';
import '../models/class_attendance_submission.dart';
import '../models/class_schedule.dart';
import '../app/app_controller.dart';

class ApiService {
  // ── Controller link ────────────────────────────────────────────────────────

  AppController? _controller;

  void setController(AppController controller) {
    _controller = controller;
  }

  Future<Map<String, String>> getHeaders() async {
    final token = _controller?.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  static void Function()? onUnauthorized;

  // ── Shared request helpers ─────────────────────────────────────────────────

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

  Future<List<dynamic>> _requestList({
    required String path,
    String? token,
  }) async {
    final uri = Uri.parse('${_baseUrl()}$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(uri, headers: headers);
      final raw = response.body;
      final decoded = raw.isEmpty ? <dynamic>[] : jsonDecode(raw);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is List) {
        return decoded;
      }

      if (decoded is Map<String, dynamic>) throw Exception(_extractMessage(decoded));
      throw Exception('Unexpected response from server.');
    } on http.ClientException catch (e) {
      throw Exception('Unable to connect to the server. Make sure the backend is running. (${e.message})');
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

  Future<void> forgotPassword({required String email}) async {
    await _request(
      method: 'POST',
      path: '/forgot-password',
      body: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    await _request(
      method: 'POST',
      path: '/reset-password',
      body: {'email': email, 'otp': otp, 'password': password},
    );
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

  Future<ActivitySlot> updateSlot({
    required String token,
    required int activityId,
    required int slotId,
    required String date,
    required String time,
    required int capacity,
  }) async {
    final json = await _request(
      method: 'PUT',
      path: '/activities/$activityId/slots/$slotId',
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
    return _request(method: 'GET', path: '/adab/access', token: token);
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

  // ── Academic Sessions ──────────────────────────────────────────────────────

  Future<void> createSession(String sessionName) async {
    await _request(
      method: 'POST',
      path: '/academic-sessions',
      body: {'session_name': sessionName},
      token: _controller?.token,
    );
  }

  Future<void> deleteSession(int sessionId) async {
    await _request(
      method: 'DELETE',
      path: '/academic-sessions/$sessionId',
      token: _controller?.token,
    );
  }

  Future<void> setRegistrationStatus(int sessionId, bool isRegistrationOpen) async {
    try {
      await _request(
        method: 'POST',
        path: '/academic-sessions/$sessionId/set-registration-status',
        body: {'is_registration_open': isRegistrationOpen ? 1 : 0},
        token: _controller?.token,
      );
    } catch (e) {
      debugPrint('Error in setRegistrationStatus: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getAcademicSessions() async {
    try {
      return await _requestList(
        path: '/academic-sessions',
        token: _controller?.token,
      );
    } catch (e) {
      debugPrint('Error in getAcademicSessions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getActiveSession({required String token}) async {
    try {
      final url = Uri.parse('${_baseUrl()}/academic-sessions/active');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      final contentType = response.headers['content-type'];
      final isJson = contentType != null && contentType.contains('application/json');

      if (response.statusCode == 200 && isJson) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('getActiveSession: server error ${response.statusCode} — ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error fetching active session: $e');
      return null;
    }
  }

  // ── Subjects Management ────────────────────────────────────────────────────

  Future<List<dynamic>> getSubjects({required String token}) async {
    try {
      return await _requestList(path: '/subjects', token: token);
    } catch (e) {
      debugPrint('Error in getSubjects: $e');
      return [];
    }
  }

  Future<void> createSubject({
    required String token,
    required String code,
    required String name,
    required int creditHours,
    required List<Map<String, dynamic>> lectureSections,
    required List<Map<String, dynamic>> labSections,
  }) async {
    await _request(
      method: 'POST',
      path: '/subjects',
      token: token,
      body: {
        'code': code,
        'name': name,
        'credit_hours': creditHours,
        'lecture_sections': lectureSections,
        'lab_sections': labSections,
      },
    );
  }

  // ── Subject Registration Workflow ──────────────────────────────────────────

  Future<Map<String, dynamic>> registerStudentSubject({
    required String token,
    required int subjectId,
    required String lectureSection,
    String? lectureInstructor,
    String? lectureSchedule,
    String? labSection,
    String? labInstructor,
    String? labSchedule,
  }) async {
    final body = <String, dynamic>{
      'subject_id': subjectId,
      'lecture_section': lectureSection,
      'lecture_instructor': lectureInstructor,
      'lecture_schedule': lectureSchedule,
      'lab_section': labSection,
      'lab_instructor': labInstructor,
      'lab_schedule': labSchedule,
    }..removeWhere((key, value) => value == null);

    return _request(
      method: 'POST',
      path: '/student/subject-registrations',
      token: token,
      body: body,
    );
  }

  Future<void> unregisterStudentSubject({
    required String token,
    required int subjectId,
  }) async {
    await _request(
      method: 'DELETE',
      path: '/student/subject-registrations/$subjectId',
      token: token,
    );
  }

  Future<Map<String, dynamic>> submitSubjectRegistration({required String token}) async {
    return _request(
      method: 'POST',
      path: '/student/subject-registrations/submit',
      token: token,
    );
  }

  Future<Map<String, dynamic>> getStudentSubjectRegistrations({required String token}) async {
    return _request(
      method: 'GET',
      path: '/student/subject-registrations',
      token: token,
    );
  }

  // ── Lecturer/PA: Subject Registration Approval ─────────────────────────────

  Future<List<dynamic>> getPendingStudents({required String token}) async {
    final response = await _request(
      method: 'GET',
      path: '/lecturer/subject-registrations/pending',
      token: token,
    );
    return (response['students'] as List<dynamic>?) ?? [];
  }

  Future<List<dynamic>> getStudentPendingSubjects({
    required String token,
    required int studentId,
  }) async {
    final response = await _request(
      method: 'GET',
      path: '/lecturer/student/$studentId/pending-subjects',
      token: token,
    );
    return (response['subjects'] as List<dynamic>?) ?? [];
  }

  Future<void> approveAllRegistrations({required String token, required int studentId}) async {
    await _request(
      method: 'POST',
      path: '/lecturer/student/$studentId/approve-all',
      token: token,
    );
  }

  // ── Class Attendance (Lecturer) ────────────────────────────────────────────

  Future<List<ClassScheduleModel>> getLecturerClassSchedules({required String token}) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/schedules', token: token);
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClassScheduleModel>> getLecturerTodaySchedules({required String token}) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/schedules/today', token: token);
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSessionModel> startAttendanceSession({
    required String token,
    required int scheduleId,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/lecturer/attendance/sessions/start',
      token: token,
      body: {'schedule_id': scheduleId},
    );
    return AttendanceSessionModel.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<AttendanceSessionModel> generateAttendanceCode({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/lecturer/attendance/sessions/$sessionId/generate-code',
      token: token,
    );
    return AttendanceSessionModel.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<LiveAttendanceModel> getLiveAttendance({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(
      method: 'GET',
      path: '/lecturer/attendance/sessions/$sessionId/live',
      token: token,
    );
    return LiveAttendanceModel.fromJson(json);
  }

  Future<AttendanceSessionModel> closeAttendanceSession({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/lecturer/attendance/sessions/$sessionId/close',
      token: token,
    );
    return AttendanceSessionModel.fromJson(json['session'] as Map<String, dynamic>);
  }

  Future<AttendanceRecordModel> getAttendanceRecord({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(
      method: 'GET',
      path: '/lecturer/attendance/sessions/$sessionId/record',
      token: token,
    );
    return AttendanceRecordModel.fromJson(json);
  }

  Future<List<ReportClassModel>> getAttendanceReportFilters({required String token}) async {
    final json = await _request(
      method: 'GET',
      path: '/lecturer/attendance/report/filters',
      token: token,
    );
    return (json['classes'] as List<dynamic>)
        .map((e) => ReportClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReportSummaryModel> generateAttendanceReport({
    required String token,
    required int classId,
  }) async {
    final json = await _request(
      method: 'GET',
      path: '/lecturer/attendance/report?class_id=$classId',
      token: token,
    );
    return ReportSummaryModel.fromJson(json);
  }

  // ── Class Attendance (Student) ─────────────────────────────────────────────

  Future<List<ClassScheduleModel>> getStudentClassSchedules({required String token}) async {
    final json = await _request(
      method: 'GET',
      path: '/student/attendance/schedules',
      token: token,
    );
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSessionModel?> getActiveAttendanceSession({
    required String token,
    required int scheduleId,
  }) async {
    final json = await _request(
      method: 'GET',
      path: '/student/attendance/schedules/$scheduleId/active-session',
      token: token,
    );
    final session = json['session'];
    if (session == null) return null;
    return AttendanceSessionModel.fromJson(session as Map<String, dynamic>);
  }

  Future<String> submitClassAttendance({
    required String token,
    required int scheduleId,
    required String attendanceCode,
    required double latitude,
    required double longitude,
  }) async {
    final json = await _request(
      method: 'POST',
      path: '/student/attendance/submit',
      token: token,
      body: {
        'schedule_id': scheduleId,
        'attendance_code': attendanceCode,
        'gps_latitude': latitude,
        'gps_longitude': longitude,
      },
    );
    return json['message'] as String? ?? 'Attendance marked successfully.';
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

  String receiptDownloadUrl(int paymentId) => '${_baseUrl()}/receipts/$paymentId/download';

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

  String _baseUrl() => 'http://127.0.0.1:8000/api';

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
