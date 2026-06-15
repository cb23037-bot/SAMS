import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/activity.dart';
import '../models/activity_registration.dart';
import '../models/activity_slot.dart';
import '../models/app_user.dart';
import '../app/app_controller.dart';

/// Handles all HTTP communication between the Flutter app and the Laravel backend.
///
/// Every public method in this class corresponds to one API endpoint.
/// The class uses a shared private [_request] helper to avoid duplicating
/// headers, error handling, and JSON parsing across every method.
///
/// File uploads (proof PDF, attendance photo) use multipart/form-data manually
/// because the http package's MultipartRequest is cleaner for this use case.
class ApiService {
  static void Function()? onUnauthorized;

  // ── Controller link ────────────────────────────────────────────────────────

  /// Optional back-reference to the [AppController], set via [setController].
  /// Lets newer endpoints (academic sessions, subject registration) read the
  /// current Bearer token without it being passed explicitly on every call.
  AppController? _controller;

  /// Links this service to the app's [AppController] so [_controller] —
  /// and therefore the current auth token — becomes available.
  void setController(AppController controller) {
    _controller = controller;
  }

  /// Builds standard JSON headers, including the Bearer token from
  /// [_controller] if one has been linked via [setController].
  Future<Map<String, String>> getHeaders() async {
    final token = _controller?.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── Shared request helpers ─────────────────────────────────────────────────

  /// Generic HTTP request handler used by all non-file-upload methods.
  ///
  /// Handles: setting headers, encoding the request body as JSON,
  /// decoding the response, checking status codes, and extracting error
  /// messages. Throws an [Exception] on HTTP errors or connection failures.
  ///
  /// [method]  — HTTP verb: 'GET', 'POST', 'PUT', or 'DELETE'
  /// [path]    — API path relative to base URL (e.g. '/activities')
  /// [token]   — Bearer token for authenticated routes; null for public routes
  /// [body]    — Optional JSON body, only sent for POST and PUT
  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('${_baseUrl()}$path');
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };

      http.Response response;
      switch (method) {
        case 'GET':
          response = await client.get(uri, headers: headers);
        case 'POST':
          response = await client.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        case 'PUT':
          response = await client.put(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        case 'DELETE':
          response = await client.delete(uri, headers: headers);
        default:
          throw Exception('Unsupported method: $method');
      }

      final json = _decodeJson(response.body, response.statusCode);
      if (response.statusCode >= 200 && response.statusCode < 300) return json;
      throw Exception(_extractMessage(json));
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close();
    }
  }

  /// Like [_request], but for GET endpoints whose JSON response is a top-level
  /// list (e.g. `/academic-sessions`, `/subjects`) rather than an object.
  Future<List<dynamic>> _requestList({
    required String path,
    String? token,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('${_baseUrl()}$path');
      final headers = <String, String>{
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await client.get(uri, headers: headers);
      final raw = response.body;
      final decoded = raw.isEmpty ? <dynamic>[] : jsonDecode(raw);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is List) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) throw Exception(_extractMessage(decoded));
      throw Exception('Unexpected response from server.');
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close();
    }
  }

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Sends login credentials to the backend and returns a [LoginResponse]
  /// containing the Sanctum token and the authenticated user's data.
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

  /// Revokes the current session token on the backend (Laravel Sanctum delete token).
  /// Called when the user taps the logout button.
  Future<void> logout({required String token}) async {
    await _request(method: 'POST', path: '/logout', token: token);
  }

  /// Requests a one-time password (OTP) be emailed to [email] so the user
  /// can reset their password.
  Future<void> forgotPassword({required String email}) async {
    await _request(
      method: 'POST',
      path: '/forgot-password',
      body: {'email': email},
    );
  }

  /// Verifies the [otp] sent to [email] and sets a new [password] for the
  /// account.
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

  /// Updates editable profile fields for the currently authenticated user.
  /// Returns the full updated [AppUser] so [AppController] can replace
  /// its [currentUser] immediately without needing a separate GET call.
  Future<AppUser> updateProfile({
    required String token,
    required Map<String, dynamic> fields,
  }) async {
    final json = await _request(method: 'PUT', path: '/profile', token: token, body: fields);
    return AppUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  // ── Curriculum Activities ──────────────────────────────────────────────────

  /// Fetches all curriculum activities from the backend, each including
  /// their nested list of slots. Used by both the student KoQ booking page
  /// and the Pusat Adab manage activities page.
  Future<List<Activity>> getActivities({required String token}) async {
    final json = await _request(method: 'GET', path: '/activities', token: token);
    return (json['activities'] as List<dynamic>)
        .map((a) => Activity.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new curriculum activity. [code] is auto-generated by the backend
  /// if not provided. Only Pusat Adab users can call this successfully.
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
        // Only include optional fields if they have a value
        if (code != null && code.isNotEmpty) 'code': code,
        if (whatsappLink != null && whatsappLink.isNotEmpty) 'whatsapp_link': whatsappLink,
        if (description != null && description.isNotEmpty) 'description': description,
      },
    );
    return Activity.fromJson(json['activity'] as Map<String, dynamic>);
  }

  /// Updates an existing curriculum activity by its [id].
  /// All main fields are required; optional fields default to empty string
  /// to allow clearing them on the backend.
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

  /// Deletes a curriculum activity and all its associated slots.
  /// Only Pusat Adab users have permission on this endpoint.
  Future<void> deleteActivity({required String token, required int id}) async {
    await _request(method: 'DELETE', path: '/activities/$id', token: token);
  }

  // ── Activity Slots ─────────────────────────────────────────────────────────

  /// Adds a new date/time slot to an existing activity.
  /// [capacity] controls how many students can register for this slot.
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

  /// Updates the date, time, and capacity of an existing slot.
  /// Requires both [activityId] and [slotId] because the route is nested:
  /// PUT /activities/{activity}/slots/{slot}
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

  /// Deletes a specific slot from an activity.
  /// Requires both [activityId] and [slotId] because the route is nested:
  /// DELETE /activities/{activity}/slots/{slot}
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

  /// Fetches all activity registrations belonging to the authenticated student.
  /// Each registration includes the activity info, slot info, claim status,
  /// and whether a proof document has been uploaded.
  Future<List<ActivityRegistration>> getStudentRegistrations({required String token}) async {
    final json = await _request(method: 'GET', path: '/student/registrations', token: token);
    return (json['registrations'] as List<dynamic>)
        .map((r) => ActivityRegistration.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Registers the authenticated student for a specific activity slot.
  /// The backend validates capacity limits and duplicate registrations.
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

  /// Cancels a registration (only allowed before attendance is submitted).
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

  /// Submits a credit claim with a proof document (PDF or image).
  ///
  /// Uses multipart/form-data instead of JSON because we are sending a file.
  /// The boundary string is a unique separator that tells the server where
  /// each part of the multipart body begins and ends.
  ///
  /// On success, the backend updates claim_status to 'pending' and returns
  /// the updated registration record.
  Future<ActivityRegistration> claimWithProof({
    required String token,
    required int registrationId,
    required String filePath,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse('${_baseUrl()}/student/registrations/$registrationId/claim');
      final ext = fileName.toLowerCase().split('.').last;
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'pdf'           => 'application/pdf',
        _               => 'application/octet-stream',
      };

      final fileBytes = await File(filePath).readAsBytes();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(http.MultipartFile.fromBytes(
          'proof', fileBytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ));

      final streamed = await request.send();
      final raw = await streamed.stream.bytesToString();
      final json = _decodeJson(raw, streamed.statusCode);

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return ActivityRegistration.fromJson(json['registration'] as Map<String, dynamic>);
      }
      throw Exception(_extractMessage(json));
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    }
  }

  // ── Attendance Submission ──────────────────────────────────────────────────

  /// Submits the student's attendance for a specific slot.
  ///
  /// Requires the 6-character attendance code displayed by Pusat Adab,
  /// a selfie photo, and optionally the device's GPS coordinates.
  /// The backend verifies the code, records the location, and generates
  /// a unique receipt ID and hash for verification purposes.
  ///
  /// Uses multipart/form-data to send both text fields and the photo file
  /// in a single request.
  Future<AttendanceResult> submitAttendance({
    required String token,
    required int slotId,
    required String attendanceCode,
    required String photoPath,
    required String photoName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final uri = Uri.parse('${_baseUrl()}/student/attendances');
      final ext = photoName.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final fileBytes = await File(photoPath).readAsBytes();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['slot_id'] = '$slotId'
        ..fields['attendance_code'] = attendanceCode;

      if (latitude != null) request.fields['latitude'] = '$latitude';
      if (longitude != null) request.fields['longitude'] = '$longitude';
      if (address != null) request.fields['address'] = address;

      request.files.add(http.MultipartFile.fromBytes(
        'photo', fileBytes,
        filename: photoName,
        contentType: MediaType.parse(mimeType),
      ));

      final streamed = await request.send();
      final raw = await streamed.stream.bytesToString();
      final json = _decodeJson(raw, streamed.statusCode);

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final sub = json['submission'] as Map<String, dynamic>;
        return AttendanceResult(
          receiptId: sub['receipt_id'] as String,
          receiptHash: sub['receipt_hash'] as String,
        );
      }
      throw Exception(_extractMessage(json));
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    }
  }

  /// Withdraws a pending credit claim, resetting claim_status back to 'not_claimed'.
  /// This allows the student to re-submit with a different proof file.
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

  /// Checks whether Pusat Adab has opened student access (registration & claims).
  /// Returns true if open, false if closed. Used by the student home page to
  /// show or hide registration and claim buttons.
  Future<bool> getStudentAccessOpen({required String token}) async {
    final json = await _request(method: 'GET', path: '/student/access', token: token);
    return (json['student_access'] as String) == 'open';
  }

  // ── Pusat Adab: Access Control ─────────────────────────────────────────────

  /// Fetches the current student access state for the Pusat Adab dashboard.
  Future<bool> getAdabAccess({required String token}) async {
    final json = await _request(method: 'GET', path: '/adab/access', token: token);
    return (json['student_access'] as String) == 'open';
  }

  /// Toggles student access open or closed.
  /// [open] = true opens access; false closes it.
  /// Returns the new state from the server to confirm the change was applied.
  Future<bool> setAdabAccess({required String token, required bool open}) async {
    final json = await _request(
      method: 'PUT',
      path: '/adab/access',
      token: token,
      body: {'status': open ? 'open' : 'closed'},
    );
    return (json['student_access'] as String) == 'open';
  }

  // ── Pusat Adab: Credit Claim Management ───────────────────────────────────

  /// Fetches all pending credit claims for the Pusat Adab notification page.
  /// Returns pending_count and a list of claim details.
  Future<Map<String, dynamic>> getAdabNotifications({required String token}) async {
    return _request(method: 'GET', path: '/adab/notifications', token: token);
  }

  /// Fetches the claims overview for the Manage Claims page.
  /// Returns global stats (total, pending, approved, rejected) and a list
  /// of activities that have at least one claim submitted.
  Future<Map<String, dynamic>> getClaimsOverview({required String token}) async {
    return _request(method: 'GET', path: '/adab/claims', token: token);
  }

  /// Fetches all individual student claims for a specific activity.
  /// Used when Pusat Adab drills into a specific activity to see per-student claims.
  Future<Map<String, dynamic>> getActivityClaims({
    required String token,
    required int activityId,
  }) async {
    return _request(method: 'GET', path: '/adab/claims/$activityId', token: token);
  }

  /// Approves a student's credit claim. Optional [remarks] can be included
  /// as feedback to the student. Updates claim_status to 'claimed'.
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

  /// Rejects a student's credit claim with a mandatory [reason].
  /// Updates claim_status to 'rejected'. The reason is stored so the
  /// student can see why their claim was rejected.
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

  /// Downloads the proof document (PDF) for a claim as raw bytes.
  ///
  /// Fetched directly from the `storage/` static path (served by Laravel's
  /// `public/storage` symlink) instead of going through a JSON/base64
  /// controller response — the PHP dev server truncates large JSON bodies,
  /// but static file serving streams the full file correctly.
  Future<Uint8List> downloadProof({required String proofPath}) async {
    try {
      final uri = Uri.parse('${_storageBaseUrl()}/storage/$proofPath');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Proof document not found.');
      }
      return response.bodyBytes;
    } on http.ClientException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    }
  }

  // ── Academic Sessions (Open Registration) ─────────────────────────────────
  //
  // NOTE: these endpoints (and /subjects, /student/subject-registrations,
  // /lecturer/...) require backend controllers that are not part of this
  // codebase yet (AcademicSessionController, SubjectController,
  // SubjectRegistrationController). Calls will 404/500 until that backend
  // work lands.

  /// Creates a new academic session (e.g. "2025/2026 Semester 1").
  Future<void> createSession(String sessionName) async {
    await _request(
      method: 'POST',
      path: '/academic-sessions',
      body: {'session_name': sessionName},
      token: _controller?.token,
    );
  }

  /// Deletes an academic session by [sessionId].
  Future<void> deleteSession(int sessionId) async {
    await _request(
      method: 'DELETE',
      path: '/academic-sessions/$sessionId',
      token: _controller?.token,
    );
  }

  /// Opens or closes subject registration for the given academic session.
  Future<void> setRegistrationStatus(int sessionId, bool isRegistrationOpen) async {
    try {
      await _request(
        method: 'POST',
        path: '/academic-sessions/$sessionId/set-registration-status',
        body: {
          'is_registration_open': isRegistrationOpen ? 1 : 0,
        },
        token: _controller?.token,
      );
    } catch (e) {
      debugPrint('Error in setRegistrationStatus: $e');
      rethrow;
    }
  }

  /// Fetches all academic sessions for the Faculty Registrar session
  /// management page. Returns an empty list on error so the UI can still render.
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

  /// Fetches the currently active academic session, or null if none is
  /// active / the request fails.
  Future<Map<String, dynamic>?> getActiveSession({required String token}) async {
    try {
      final url = Uri.parse('${_baseUrl()}/academic-sessions/active');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
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

  /// Fetches all subjects offered in the active session. Returns an empty
  /// list on error so the UI can still render.
  Future<List<dynamic>> getSubjects({required String token}) async {
    try {
      return await _requestList(path: '/subjects', token: token);
    } catch (e) {
      debugPrint('Error in getSubjects: $e');
      return [];
    }
  }

  /// Creates a new subject with its lecture and lab sections.
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

  /// Registers a student for a subject with the chosen lecture/lab sections.
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
    // Build the body and drop null section fields (e.g. subjects with no lab).
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

  /// Unregisters a student from a subject.
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

  /// Submits all of the student's selected subject registrations for
  /// lecturer/advisor approval.
  Future<Map<String, dynamic>> submitSubjectRegistration({required String token}) async {
    return _request(
      method: 'POST',
      path: '/student/subject-registrations/submit',
      token: token,
    );
  }

  /// Fetches the authenticated student's current subject registrations.
  Future<Map<String, dynamic>> getStudentSubjectRegistrations({required String token}) async {
    return _request(
      method: 'GET',
      path: '/student/subject-registrations',
      token: token,
    );
  }

  // ── Lecturer/PA: Subject Registration Approval ─────────────────────────────

  /// Fetches the students who currently have pending subject registrations
  /// awaiting this lecturer/PA's approval.
  Future<List<dynamic>> getPendingStudents({required String token}) async {
    final response = await _request(
      method: 'GET',
      path: '/lecturer/subject-registrations/pending',
      token: token,
    );
    return (response['students'] as List<dynamic>?) ?? [];
  }

  /// Fetches the pending subject registrations for one specific student.
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

  /// Approves all of a student's pending subject registrations at once.
  Future<void> approveAllRegistrations({required String token, required int studentId}) async {
    await _request(
      method: 'POST',
      path: '/lecturer/student/$studentId/approve-all',
      token: token,
    );
  }

  // ── Module 3: Fees (Student) ──────────────────────────────────────────────

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

  // ── Module 3: Fees (Treasury) ─────────────────────────────────────────────

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

  // ── Module 3: Restriction ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRestrictionStatus({required String token}) async {
    return _request(method: 'GET', path: '/student/restriction-status', token: token);
  }

  Future<Map<String, dynamic>> getStudentSponsors({required String token}) async {
    return _request(method: 'GET', path: '/student/sponsors', token: token);
  }

  Future<Map<String, dynamic>> getStudentLedger({required String token}) async {
    return _request(method: 'GET', path: '/student/ledger', token: token);
  }

  Future<void> applyRestriction({required String token, required int userId}) async {
    await _request(method: 'POST', path: '/treasury/restrict/$userId', token: token);
  }

  Future<void> liftRestriction({required String token, required int userId}) async {
    await _request(method: 'DELETE', path: '/treasury/restrict/$userId', token: token);
  }

  // ── Module 3: Notifications ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications({required String token}) async {
    return _request(method: 'GET', path: '/notifications', token: token);
  }

  Future<void> markNotificationRead({required String token, required int id}) async {
    await _request(method: 'PUT', path: '/notifications/$id/read', token: token);
  }

  Future<void> markAllNotificationsRead({required String token}) async {
    await _request(method: 'PUT', path: '/notifications/read-all', token: token);
  }

  // ── Module 3: Receipt PDF ─────────────────────────────────────────────────

  String receiptDownloadUrl(int paymentId) =>
      '${_baseUrl()}/receipts/$paymentId/download';

  // ── Private Helpers ────────────────────────────────────────────────────────

  /// Returns the correct base URL depending on the platform.
  ///
  /// For an Android emulator, change this to `http://10.0.2.2:8000/api`
  /// (the emulator's alias for the host machine's localhost). For a
  /// physical device over USB, run `adb reverse tcp:8000 tcp:8000` so its
  /// 127.0.0.1 reaches the host, same as web and other platforms.
  String _baseUrl() {
    return 'http://127.0.0.1:8000/api';
  }

  /// Returns the server's root URL (without the `/api` suffix), used to
  /// fetch static files served from Laravel's `public/storage` symlink.
  String _storageBaseUrl() {
    final base = _baseUrl();
    return base.substring(0, base.length - '/api'.length);
  }

  /// Safely decodes a JSON response body.
  ///
  /// If the server returns a non-JSON body (e.g. an HTML error page from a
  /// 500 server error), `jsonDecode` throws a [FormatException] whose message
  /// includes the raw HTML — this would otherwise leak onto the screen via
  /// `e.toString()`. Instead, throw a clean, user-friendly [Exception].
  Map<String, dynamic> _decodeJson(String raw, int statusCode) {
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Server error (code $statusCode). Please try again later.');
    }
  }

  /// Extracts a human-readable error message from the backend's JSON response.
  ///
  /// Laravel returns errors in two formats:
  /// 1. { "message": "Some error" }
  /// 2. { "errors": { "field": ["Validation error message"] } }
  ///
  /// This method handles both and falls back to a generic message if neither
  /// format is present.
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

/// Holds the result of a successful login: the Sanctum token and user data.
class LoginResponse {
  const LoginResponse({required this.token, required this.user});
  final String token;
  final AppUser user;
}

/// Holds the receipt details returned after a successful attendance submission.
/// The [receiptId] is a short readable ID; [receiptHash] is a verification hash.
class AttendanceResult {
  const AttendanceResult({required this.receiptId, required this.receiptHash});
  final String receiptId;
  final String receiptHash;
}

/// Carries an optional error [code] (e.g. DB_ERROR, GATEWAY_UNAVAILABLE)
/// so callers can branch on specific failure types.
class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}
