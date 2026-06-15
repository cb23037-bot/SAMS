import 'attendance_session.dart';

/// Represents a single student's attendance submission for a session.
///
/// Created when a student successfully submits their attendance code and GPS
/// location. Used in the lecturer's live view (SAMS-PACK-408) and the
/// attendance record page (SAMS-PACK-409).
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

  /// Unique identifier for this submission record.
  final int attendanceSubmissionId;

  /// The ID of the student who submitted.
  final int studentId;

  /// Full name of the student.
  final String studentName;

  /// Student's matric number.
  final String matricNo;

  /// The attendance code the student entered at submission time.
  final String submittedCode;

  /// ISO 8601 timestamp of when the student submitted.
  final String submittedAt;

  /// GPS latitude recorded at submission time.
  final double gpsLatitude;

  /// GPS longitude recorded at submission time.
  final double gpsLongitude;

  /// Submission status: 'present' if accepted, 'rejected' if flagged.
  final String attendanceStatus;

  /// Returns true when the submission was accepted as present.
  bool get isPresent => attendanceStatus == 'present';

  /// Deserialises a [ClassAttendanceSubmissionModel] from the API JSON response.
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

/// Represents a student who was enrolled in a class but did not submit
/// attendance for a session (i.e. marked as absent).
///
/// Used in the attendance record page (SAMS-PACK-409) absent tab.
class AbsentStudentModel {
  const AbsentStudentModel({
    required this.studentId,
    required this.name,
    required this.matricNo,
  });

  /// The ID of the absent student.
  final int studentId;

  /// Full name of the absent student.
  final String name;

  /// Matric number of the absent student.
  final String matricNo;

  /// Deserialises an [AbsentStudentModel] from the API JSON response.
  factory AbsentStudentModel.fromJson(Map<String, dynamic> json) {
    return AbsentStudentModel(
      studentId: (json['student_id'] as num).toInt(),
      name: json['name'] as String,
      matricNo: json['matric_no'] as String? ?? 'N/A',
    );
  }
}

/// Represents the live state of an attendance session polled by the lecturer.
///
/// Returned by the getLiveSubmissions endpoint every 5 seconds while the
/// session is active. Used in SAMS-PACK-408 (lecturer active session page).
class LiveAttendanceModel {
  const LiveAttendanceModel({
    required this.session,
    required this.enrolledCount,
    required this.submittedCount,
    required this.submissions,
  });

  /// The current state of the attendance session.
  final AttendanceSessionModel session;

  /// Total number of students enrolled in the class.
  final int enrolledCount;

  /// Number of students who have submitted attendance so far.
  final int submittedCount;

  /// List of all submission records received so far, ordered by submitted_at desc.
  final List<ClassAttendanceSubmissionModel> submissions;

  /// Deserialises a [LiveAttendanceModel] from the API JSON response.
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

/// Represents the full attendance record for one session:
/// present students, rejected submissions, and absent students.
///
/// Returned by the viewRecord endpoint and used in SAMS-PACK-409
/// (lecturer attendance record page).
class AttendanceRecordModel {
  const AttendanceRecordModel({
    required this.session,
    required this.present,
    required this.rejected,
    required this.absent,
  });

  /// The session these records belong to.
  final AttendanceSessionModel session;

  /// Students whose submission was accepted (status = 'present').
  final List<ClassAttendanceSubmissionModel> present;

  /// Students whose submission was flagged (status = 'rejected').
  final List<ClassAttendanceSubmissionModel> rejected;

  /// Students enrolled in the class who did not submit at all.
  final List<AbsentStudentModel> absent;

  /// Deserialises an [AttendanceRecordModel] from the API JSON response.
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
