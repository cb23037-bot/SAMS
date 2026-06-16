/// Wraps the backend response from POST /lecturer/attendance/sessions/start.
///
/// The backend returns HTTP 201 for a new session and HTTP 200 (with the same
/// body shape) when a session is already active. [alreadyActive] distinguishes
/// the two cases so the UI can surface an appropriate message.
class StartSessionResult {
  const StartSessionResult({
    required this.session,
    required this.alreadyActive,
  });

  final AttendanceSessionModel session;

  /// True when the backend returned an existing active session (HTTP 200).
  final bool alreadyActive;
}

/// Represents an attendance session opened by a lecturer for a class.
///
/// A session is created when the lecturer taps "Start Attendance Session"
/// and remains active until the lecturer closes it. Students can only submit
/// attendance while the session [isActive].
class AttendanceSessionModel {
  const AttendanceSessionModel({
    required this.attendanceSessionId,
    required this.classId,
    required this.scheduleId,
    required this.attendanceCode,
    required this.sessionDate,
    required this.startedAt,
    this.closedAt,
    required this.status,
    this.alreadySubmitted = false,
  });

  /// Unique identifier for this attendance session.
  final int attendanceSessionId;

  /// The class this session belongs to.
  final int classId;

  /// The specific schedule (timetable slot) this session was started for.
  final int scheduleId;

  /// The current attendance code students must enter to mark attendance.
  /// Changes each time the lecturer generates a new code.
  final String attendanceCode;

  /// The date (YYYY-MM-DD) on which this session was held.
  final String sessionDate;

  /// ISO 8601 timestamp when the session was started.
  final String startedAt;

  /// ISO 8601 timestamp when the session was closed. Null if still active.
  final String? closedAt;

  /// Session lifecycle status: 'active' or 'closed'.
  final String status;

  /// Student-only flag: true if the current student has already submitted
  /// attendance for this session.
  final bool alreadySubmitted;

  /// Returns true when the session is still open for submissions.
  bool get isActive => status == 'active';

  /// Deserialises an [AttendanceSessionModel] from the API JSON response.
  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      attendanceSessionId: (json['attendance_session_id'] as num).toInt(),
      classId: (json['class_id'] as num).toInt(),
      scheduleId: (json['schedule_id'] as num).toInt(),
      attendanceCode: json['attendance_code'] as String? ?? '',
      sessionDate: json['session_date'] as String,
      startedAt: json['started_at'] as String,
      closedAt: json['closed_at'] as String?,
      status: json['status'] as String,
      alreadySubmitted: json['already_submitted'] as bool? ?? false,
    );
  }
}
