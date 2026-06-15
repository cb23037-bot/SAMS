import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../models/activity_registration.dart';
import '../models/activity_slot.dart';
import '../models/app_user.dart';
import '../models/attendance_report.dart';
import '../models/attendance_session.dart';
import '../models/class_attendance_submission.dart';
import '../models/class_schedule.dart';
import '../app/app_controller.dart';
import 'package:http/http.dart' as http;

/// Handles all HTTP communication between the Flutter app and the Laravel backend.
///
/// Every public method in this class corresponds to one API endpoint.
/// The class uses a shared private [_request] helper to avoid duplicating
/// headers, error handling, and JSON parsing across every method.
///
/// File uploads (proof PDF, attendance photo) use multipart/form-data manually
/// because Dart's native [HttpClient] does not have a built-in multipart helper.
class ApiService {
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
    // Create a new client per request — prevents connection pooling issues
    // when the app goes background and sockets time out.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse('${_baseUrl()}$path');
      late HttpClientRequest req;

      // Open the correct HTTP method
      switch (method) {
        case 'GET':
          req = await client.getUrl(uri);
        case 'POST':
          req = await client.postUrl(uri);
        case 'PUT':
          req = await client.putUrl(uri);
        case 'DELETE':
          req = await client.deleteUrl(uri);
        default:
          throw Exception('Unsupported method: $method');
      }

      // Attach the Bearer token so the backend can identify the user
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      // Encode the body as JSON if provided
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }

      final response = await req.close();
      final raw = await response.transform(utf8.decoder).join();

      // Some endpoints return an empty body (e.g. DELETE), handle gracefully
      final json = _decodeJson(raw, response.statusCode);

      // 2xx = success; anything else is an API error
      if (response.statusCode >= 200 && response.statusCode < 300) return json;

      throw Exception(_extractMessage(json));
    } on SocketException {
      // Thrown when the device cannot reach the server at all
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      // Always close the client to free socket resources
      client.close(force: true);
    }
  }

  /// Like [_request], but for GET endpoints whose JSON response is a top-level
  /// list (e.g. `/academic-sessions`, `/subjects`) rather than an object.
  Future<List<dynamic>> _requestList({
    required String path,
    String? token,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse('${_baseUrl()}$path');
      final req = await client.getUrl(uri);

      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      final response = await req.close();
      final raw = await response.transform(utf8.decoder).join();
      final decoded = raw.isEmpty ? <dynamic>[] : jsonDecode(raw);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is List) {
        return decoded;
      }

      if (decoded is Map<String, dynamic>) throw Exception(_extractMessage(decoded));
      throw Exception('Unexpected response from server.');
    } on SocketException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close(force: true);
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
    // Separate client with longer timeout because file uploads take more time
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);

    try {
      final uri = Uri.parse('${_baseUrl()}/student/registrations/$registrationId/claim');
      final req = await client.postUrl(uri);

      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      // Generate a unique boundary string for this multipart request
      final boundary = '----Boundary${DateTime.now().millisecondsSinceEpoch}';
      req.headers.contentType =
          ContentType('multipart', 'form-data', parameters: {'boundary': boundary});

      // Determine MIME type from file extension so the backend knows what to expect
      final ext = fileName.toLowerCase().split('.').last;
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'pdf'           => 'application/pdf',
        _               => 'application/octet-stream',
      };

      // Build the multipart body manually as a byte buffer
      final fileBytes = await File(filePath).readAsBytes();
      final buffer = <int>[];
      buffer.addAll(utf8.encode('--$boundary\r\n'));
      buffer.addAll(utf8.encode(
          'Content-Disposition: form-data; name="proof"; filename="$fileName"\r\n'));
      buffer.addAll(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
      buffer.addAll(fileBytes);
      buffer.addAll(utf8.encode('\r\n--$boundary--\r\n'));

      req.contentLength = buffer.length;
      req.add(buffer);

      final response = await req.close();
      final raw = await response.transform(utf8.decoder).join();
      final json = _decodeJson(raw, response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ActivityRegistration.fromJson(json['registration'] as Map<String, dynamic>);
      }
      throw Exception(_extractMessage(json));
    } on SocketException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close(force: true);
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);

    try {
      final uri = Uri.parse('${_baseUrl()}/student/attendances');
      final req = await client.postUrl(uri);

      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

      final boundary = '----Boundary${DateTime.now().millisecondsSinceEpoch}';
      req.headers.contentType =
          ContentType('multipart', 'form-data', parameters: {'boundary': boundary});

      final ext = photoName.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final fileBytes = await File(photoPath).readAsBytes();
      final buffer = <int>[];

      // Helper closure to add a plain text field to the multipart body
      void addField(String name, String value) {
        buffer.addAll(utf8.encode('--$boundary\r\n'));
        buffer.addAll(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
        buffer.addAll(utf8.encode('$value\r\n'));
      }

      // Add all text fields first, then the photo file
      addField('slot_id', '$slotId');
      addField('attendance_code', attendanceCode);
      if (latitude != null) addField('latitude', '$latitude');
      if (longitude != null) addField('longitude', '$longitude');
      if (address != null) addField('address', address);

      // Add the photo as the last part of the multipart body
      buffer.addAll(utf8.encode('--$boundary\r\n'));
      buffer.addAll(utf8.encode(
          'Content-Disposition: form-data; name="photo"; filename="$photoName"\r\n'));
      buffer.addAll(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
      buffer.addAll(fileBytes);
      buffer.addAll(utf8.encode('\r\n--$boundary--\r\n'));

      req.contentLength = buffer.length;
      req.add(buffer);

      final response = await req.close();
      final raw = await response.transform(utf8.decoder).join();
      final json = _decodeJson(raw, response.statusCode);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sub = json['submission'] as Map<String, dynamic>;
        return AttendanceResult(
          receiptId: sub['receipt_id'] as String,
          receiptHash: sub['receipt_hash'] as String,
        );
      }
      throw Exception(_extractMessage(json));
    } on SocketException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close(force: true);
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse('${_storageBaseUrl()}/storage/$proofPath');
      final req = await client.getUrl(uri);
      final response = await req.close();

      if (response.statusCode != 200) {
        throw Exception('Proof document not found.');
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } on SocketException {
      throw Exception('Unable to connect to the server. Make sure the backend is running.');
    } finally {
      client.close(force: true);
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

  // ── Class Attendance (Lecturer) ────────────────────────────────────────────

  /// Fetches all class schedules assigned to the authenticated lecturer.
  Future<List<ClassScheduleModel>> getLecturerClassSchedules({required String token}) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/schedules', token: token);
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the authenticated lecturer's class schedules for today.
  Future<List<ClassScheduleModel>> getLecturerTodaySchedules({required String token}) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/schedules/today', token: token);
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Starts (or resumes) an attendance session for a class schedule.
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

  /// Generates a new attendance code for an active session.
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

  /// Fetches the live list of submissions for an active session (used for polling).
  Future<LiveAttendanceModel> getLiveAttendance({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/sessions/$sessionId/live', token: token);
    return LiveAttendanceModel.fromJson(json);
  }

  /// Closes an active attendance session.
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

  /// Fetches the full attendance record (present, rejected, absent) for a session.
  Future<AttendanceRecordModel> getAttendanceRecord({
    required String token,
    required int sessionId,
  }) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/sessions/$sessionId/record', token: token);
    return AttendanceRecordModel.fromJson(json);
  }

  /// Fetches the list of classes the lecturer can generate an attendance report for.
  Future<List<ReportClassModel>> getAttendanceReportFilters({required String token}) async {
    final json = await _request(method: 'GET', path: '/lecturer/attendance/report/filters', token: token);
    return (json['classes'] as List<dynamic>)
        .map((e) => ReportClassModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Generates the attendance report summary for a class.
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

  /// Fetches the class schedules the authenticated student is enrolled in.
  Future<List<ClassScheduleModel>> getStudentClassSchedules({required String token}) async {
    final json = await _request(method: 'GET', path: '/student/attendance/schedules', token: token);
    return (json['schedules'] as List<dynamic>)
        .map((e) => ClassScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Checks whether a class the student is enrolled in has an active attendance session.
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

  /// Submits the student's attendance code and GPS location for an active session.
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
