// ── User model ─────────────────────────────────────────────────────────────
class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? studentId;
  final String? course;
  final String status;

  UserModel({
    required this.id, required this.name, required this.email,
    required this.role, this.studentId, this.course, required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:        j['id'],
    name:      j['name'],
    email:     j['email'],
    role:      j['role'],
    studentId: j['student_id'],
    course:    j['course'],
    status:    j['status'],
  );
}

// ── ClassSchedule model ────────────────────────────────────────────────────
class ClassScheduleModel {
  final int scheduleId;
  final int classId;
  final String courseCode;
  final String courseName;
  final String className;
  final String section;
  final String day;
  final String scheduleDate;
  final String startTime;
  final String endTime;
  final String venue;
  // Student-side extras
  final AttendanceSessionModel? activeSession;
  final bool alreadySubmitted;

  ClassScheduleModel({
    required this.scheduleId, required this.classId,
    required this.courseCode, required this.courseName,
    required this.className, required this.section,
    required this.day, required this.scheduleDate,
    required this.startTime, required this.endTime,
    required this.venue,
    this.activeSession, this.alreadySubmitted = false,
  });

  factory ClassScheduleModel.fromJson(Map<String, dynamic> j) => ClassScheduleModel(
    scheduleId:       j['schedule_id'],
    classId:          j['class_id'],
    courseCode:       j['course_code'],
    courseName:       j['course_name'],
    className:        j['class_name'],
    section:          j['section'],
    day:              j['day'],
    scheduleDate:     j['schedule_date'],
    startTime:        j['start_time'],
    endTime:          j['end_time'],
    venue:            j['venue'],
    activeSession:    j['active_session'] != null
        ? AttendanceSessionModel.fromJson(j['active_session'])
        : null,
    alreadySubmitted: j['already_submitted'] ?? false,
  );
}

// ── AttendanceSession model ────────────────────────────────────────────────
class AttendanceSessionModel {
  final int attendanceSessionId;
  final int scheduleId;
  final String attendanceCode;
  final String sessionDate;
  final String startedAt;
  final String? closedAt;
  final String status;

  AttendanceSessionModel({
    required this.attendanceSessionId, required this.scheduleId,
    required this.attendanceCode, required this.sessionDate,
    required this.startedAt, this.closedAt, required this.status,
  });

  bool get isActive => status == 'active';

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> j) => AttendanceSessionModel(
    attendanceSessionId: j['attendance_session_id'],
    scheduleId:          j['schedule_id'],
    attendanceCode:      j['attendance_code'],
    sessionDate:         j['session_date'],
    startedAt:           j['started_at'],
    closedAt:            j['closed_at'],
    status:              j['status'],
  );
}

// ── AttendanceSubmission model ─────────────────────────────────────────────
class AttendanceSubmissionModel {
  final int attendanceSubmissionId;
  final int attendanceSessionId;
  final int studentId;
  final String submittedAt;
  final double gpsLatitude;
  final double gpsLongitude;
  final String attendanceStatus;
  // from with('student')
  final String? studentName;
  final String? studentMatric;

  AttendanceSubmissionModel({
    required this.attendanceSubmissionId, required this.attendanceSessionId,
    required this.studentId, required this.submittedAt,
    required this.gpsLatitude, required this.gpsLongitude,
    required this.attendanceStatus, this.studentName, this.studentMatric,
  });

  factory AttendanceSubmissionModel.fromJson(Map<String, dynamic> j) => AttendanceSubmissionModel(
    attendanceSubmissionId: j['attendance_submission_id'],
    attendanceSessionId:    j['attendance_session_id'],
    studentId:              j['student_id'],
    submittedAt:            j['submitted_at'],
    gpsLatitude:            (j['gps_latitude'] as num).toDouble(),
    gpsLongitude:           (j['gps_longitude'] as num).toDouble(),
    attendanceStatus:       j['attendance_status'],
    studentName:            j['student']?['name'],
    studentMatric:          j['student']?['student_id'],
  );
}

// ── ReportSummary model ────────────────────────────────────────────────────
class ReportSummaryModel {
  final int totalStudents;
  final int presentStudents;
  final int absentStudents;
  final double attendancePercentage;

  ReportSummaryModel({
    required this.totalStudents, required this.presentStudents,
    required this.absentStudents, required this.attendancePercentage,
  });

  factory ReportSummaryModel.fromJson(Map<String, dynamic> j) => ReportSummaryModel(
    totalStudents:          j['total_students'],
    presentStudents:        j['present_students'],
    absentStudents:         j['absent_students'],
    attendancePercentage:   (j['attendance_percentage'] as num).toDouble(),
  );
}
