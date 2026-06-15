/// Represents one row in an attendance report's session header (a single class meeting).
class ReportSessionModel {
  const ReportSessionModel({
    required this.attendanceSessionId,
    required this.sessionDate,
    required this.status,
    required this.presentCount,
  });

  final int attendanceSessionId;
  final String sessionDate;
  final String status;
  final int presentCount;

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

  final int studentId;
  final String matricNo;
  final String name;

  /// One entry per session: either 'present' or 'absent'.
  final List<String> attendance;
  final int presentCount;
  final int totalSessions;
  final double percentage;

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

/// Represents the class info shown at the top of an attendance report.
class ReportClassModel {
  const ReportClassModel({
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.section,
  });

  final int classId;
  final String courseCode;
  final String courseName;
  final String className;
  final String section;

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

/// Represents a full attendance report for a class, made up of sessions and students.
class ReportSummaryModel {
  const ReportSummaryModel({
    required this.classInfo,
    required this.sessions,
    required this.students,
  });

  final ReportClassModel classInfo;
  final List<ReportSessionModel> sessions;
  final List<ReportStudentModel> students;

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
