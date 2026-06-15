import 'attendance_session.dart';

/// Represents a single student's attendance submission for a session.
class ClassAttendanceSubmissionModel {
  const ClassAttendanceSubmissionModel({
    required this.attendanceSubmissionId,
    required this.studentId,
    required this.studentName,
    required this.matricNo,
    required this.submittedCode,
    required this.submittedAt,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.attendanceStatus,
  });

  final int attendanceSubmissionId;
  final int studentId;
  final String studentName;
  final String matricNo;
  final String submittedCode;
  final String submittedAt;
  final double gpsLatitude;
  final double gpsLongitude;
  final String attendanceStatus;

  bool get isPresent => attendanceStatus == 'present';

  factory ClassAttendanceSubmissionModel.fromJson(Map<String, dynamic> json) {
    return ClassAttendanceSubmissionModel(
      attendanceSubmissionId: (json['attendance_submission_id'] as num).toInt(),
      studentId: (json['student_id'] as num).toInt(),
      studentName: json['student_name'] as String,
      matricNo: json['matric_no'] as String,
      submittedCode: json['submitted_code'] as String,
      submittedAt: json['submitted_at'] as String,
      gpsLatitude: (json['gps_latitude'] as num).toDouble(),
      gpsLongitude: (json['gps_longitude'] as num).toDouble(),
      attendanceStatus: json['attendance_status'] as String,
    );
  }
}

/// Represents a student in an attendance record who did not submit.
class AbsentStudentModel {
  const AbsentStudentModel({
    required this.studentId,
    required this.name,
    required this.matricNo,
  });

  final int studentId;
  final String name;
  final String matricNo;

  factory AbsentStudentModel.fromJson(Map<String, dynamic> json) {
    return AbsentStudentModel(
      studentId: (json['student_id'] as num).toInt(),
      name: json['name'] as String,
      matricNo: json['matric_no'] as String? ?? 'N/A',
    );
  }
}

/// Represents the live state of an attendance session for the lecturer's polling view.
class LiveAttendanceModel {
  const LiveAttendanceModel({
    required this.session,
    required this.enrolledCount,
    required this.submittedCount,
    required this.submissions,
  });

  final AttendanceSessionModel session;
  final int enrolledCount;
  final int submittedCount;
  final List<ClassAttendanceSubmissionModel> submissions;

  factory LiveAttendanceModel.fromJson(Map<String, dynamic> json) {
    return LiveAttendanceModel(
      session: AttendanceSessionModel.fromJson(json['session'] as Map<String, dynamic>),
      enrolledCount: (json['enrolled_count'] as num).toInt(),
      submittedCount: (json['submitted_count'] as num).toInt(),
      submissions: (json['submissions'] as List<dynamic>)
          .map((e) => ClassAttendanceSubmissionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents the full attendance record for one session: present, rejected and absent students.
class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.session,
    required this.present,
    required this.rejected,
    required this.absent,
  });

  final AttendanceSessionModel session;
  final List<ClassAttendanceSubmissionModel> present;
  final List<ClassAttendanceSubmissionModel> rejected;
  final List<AbsentStudentModel> absent;

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      session: AttendanceSessionModel.fromJson(json['session'] as Map<String, dynamic>),
      present: (json['present'] as List<dynamic>)
          .map((e) => ClassAttendanceSubmissionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      rejected: (json['rejected'] as List<dynamic>)
          .map((e) => ClassAttendanceSubmissionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      absent: (json['absent'] as List<dynamic>)
          .map((e) => AbsentStudentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
