import 'attendance_session.dart';

/// Represents a class schedule entry, shown to both lecturers and students.
class ClassScheduleModel {
  const ClassScheduleModel({
    required this.scheduleId,
    required this.classId,
    required this.courseCode,
    required this.courseName,
    required this.className,
    required this.section,
    required this.semester,
    required this.academicSession,
    required this.day,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.enrolledCount,
    this.lecturerName,
    this.hasActiveSession = false,
    this.alreadySubmitted = false,
    this.activeSession,
  });

  final int scheduleId;
  final int classId;
  final String courseCode;
  final String courseName;
  final String className;
  final String section;
  final String semester;
  final String academicSession;
  final String day;
  final String scheduleDate;
  final String startTime;
  final String endTime;
  final String venue;

  /// Lecturer view only: number of students enrolled in this class.
  final int? enrolledCount;

  /// Student view only: name of the lecturer teaching this class.
  final String? lecturerName;

  /// Student view only: whether the class currently has an active session.
  final bool hasActiveSession;

  /// Student view only: whether the student already submitted attendance.
  final bool alreadySubmitted;

  /// Lecturer view only: the active attendance session, if any.
  final AttendanceSessionModel? activeSession;

  factory ClassScheduleModel.fromJson(Map<String, dynamic> json) {
    return ClassScheduleModel(
      scheduleId: (json['schedule_id'] as num).toInt(),
      classId: (json['class_id'] as num).toInt(),
      courseCode: json['course_code'] as String,
      courseName: json['course_name'] as String,
      className: json['class_name'] as String,
      section: json['section'] as String,
      semester: json['semester'] as String,
      academicSession: json['academic_session'] as String,
      day: json['day'] as String,
      scheduleDate: json['schedule_date'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      venue: json['venue'] as String,
      enrolledCount: (json['enrolled_count'] as num?)?.toInt(),
      lecturerName: json['lecturer_name'] as String?,
      hasActiveSession: json['has_active_session'] as bool? ?? false,
      alreadySubmitted: json['already_submitted'] as bool? ?? false,
      activeSession: json['active_session'] != null
          ? AttendanceSessionModel.fromJson(json['active_session'] as Map<String, dynamic>)
          : null,
    );
  }
}
