import 'attendance_session.dart';

/// Represents a class schedule entry, shown to both lecturers and students.
///
/// Used in:
/// - SAMS-PACK-407 (lecturer class list) -- shows all scheduled classes.
/// - SAMS-PACK-413 (student class list) -- shows enrolled classes with session status.
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

  /// Unique identifier for this schedule row.
  final int scheduleId;

  /// The class (subject group) this schedule belongs to.
  final int classId;

  /// Subject code, e.g. "CS301".
  final String courseCode;

  /// Full subject name, e.g. "Software Engineering".
  final String courseName;

  /// Display name of the class group, e.g. "CS301-A".
  final String className;

  /// Section identifier, e.g. "A" or "1".
  final String section;

  /// Academic semester, e.g. "Semester 2".
  final String semester;

  /// Academic year/session, e.g. "2025/2026".
  final String academicSession;

  /// Day of the week this class is held, e.g. "Monday".
  final String day;

  /// Scheduled date for this class (YYYY-MM-DD).
  final String scheduleDate;

  /// Scheduled start time, e.g. "08:00".
  final String startTime;

  /// Scheduled end time, e.g. "10:00".
  final String endTime;

  /// Room or venue where the class is held.
  final String venue;

  /// Lecturer view only: number of students enrolled in this class.
  final int? enrolledCount;

  /// Student view only: name of the lecturer teaching this class.
  final String? lecturerName;

  /// Student view only: whether the class currently has an active attendance session.
  final bool hasActiveSession;

  /// Student view only: whether the student has already submitted attendance
  /// for the current active session.
  final bool alreadySubmitted;

  /// Lecturer view only: the active attendance session model, if one exists.
  final AttendanceSessionModel? activeSession;

  /// Deserialises a [ClassScheduleModel] from the API JSON response.
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
