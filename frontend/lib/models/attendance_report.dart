/// Represents one row in an attendance report's session header (a single class meeting).
///
/// Each session column in the report grid corresponds to one [ReportSessionModel].
class ReportSessionModel {
  const ReportSessionModel({
    required this.attendanceSessionId,
    required this.sessionDate,
    required this.status,
    required this.presentCount,
  });

  /// Unique identifier for this attendance session.
  final int attendanceSessionId;

  /// The date (YYYY-MM-DD) this session was held.
  final String sessionDate;

  /// Session lifecycle status: 'active' or 'closed'.
  final String status;

  /// Number of students marked present in this session.
  final int presentCount;

  /// Deserialises a [ReportSessionModel] from the API JSON response.
  factory ReportSessionModel.fromJson(Map<String, dynamic> json) {
    return ReportSessionModel(
      attendanceSessionId: (json['attendance_session_id'] as num).toInt(),
      sessionDate: json['session_date'] as String,
      status: json['status'] as String,
      presentCount: (json['present_count'] as num).toInt(),
    );
  }
}

/// Represents a single student's attendance summary across all sessions of a class.
///
/// Each row in the report grid corresponds to one [ReportStudentModel].
class ReportStudentModel {
  const ReportStudentModel({
    required this.studentId,
    required this.matricNo,
    required this.name,
    required this.attendance,
    required this.presentCount,
    required this.totalSessions,
    required this.percentage,
  });

  /// Unique identifier of the student.
  final int studentId;

  /// Student's matric number.
  final String matricNo;

  /// Student's full name.
  final String name;

  /// Per-session attendance status list: one entry per session, either
  /// 'present' or 'absent', aligned to the sessions list in [ReportSummaryModel].
  final List<String> attendance;

  /// Total number of sessions the student was marked present.
  final int presentCount;

  /// Total number of sessions held for this class.
  final int totalSessions;

  /// Attendance percentage: (presentCount / totalSessions) × 100.
  final double percentage;

  /// Deserialises a [ReportStudentModel] from the API JSON response.
  factory ReportStudentModel.fromJson(Map<String, dynamic> json) {
    return ReportStudentModel(
      studentId: (json['student_id'] as num).toInt(),
      matricNo: json['matric_no'] as String,
      name: json['name'] as String,
      attendance: (json['attendance'] as List<dynamic>).map((e) => e as String).toList(),
      presentCount: (json['present_count'] as num).toInt(),
      totalSessions: (json['total_sessions'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

/// Represents the class information shown at the top of an attendance report.
class ReportClassModel {
  const ReportClassModel({
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.section,
  });

  /// Unique identifier of the class group.
  final int classId;

  /// Subject code, e.g. "CS301".
  final String courseCode;

  /// Full subject name, e.g. "Software Engineering".
  final String courseName;

  /// Display name of the class group.
  final String className;

  /// Section identifier, e.g. "A".
  final String section;

  /// Deserialises a [ReportClassModel] from the API JSON response.
  factory ReportClassModel.fromJson(Map<String, dynamic> json) {
    return ReportClassModel(
      classId: (json['class_id'] as num).toInt(),
      courseCode: json['course_code'] as String,
      courseName: json['course_name'] as String,
      className: json['class_name'] as String,
      section: json['section'] as String,
    );
  }
}

/// Represents a full attendance report for a class, combining class info,
/// session columns, and per-student attendance rows.
///
/// Returned by [AttendanceReportController.generateReport()] and used in
/// SAMS-PACK-410 (lecturer attendance report page).
class ReportSummaryModel {
  const ReportSummaryModel({
    required this.classInfo,
    required this.sessions,
    required this.students,
  });

  /// Class metadata shown in the report header.
  final ReportClassModel classInfo;

  /// Ordered list of sessions — each maps to one column in the report grid.
  final List<ReportSessionModel> sessions;

  /// Ordered list of students — each maps to one row in the report grid.
  final List<ReportStudentModel> students;

  /// Deserialises a [ReportSummaryModel] from the API JSON response.
  factory ReportSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReportSummaryModel(
      classInfo: ReportClassModel.fromJson(json['class'] as Map<String, dynamic>),
      sessions: (json['sessions'] as List<dynamic>)
          .map((e) => ReportSessionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      students: (json['students'] as List<dynamic>)
          .map((e) => ReportStudentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
