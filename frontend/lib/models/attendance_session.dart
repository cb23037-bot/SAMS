/// Represents an attendance session opened by a lecturer for a class.
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

  final int attendanceSessionId;
  final int classId;
  final int scheduleId;
  final String attendanceCode;
  final String sessionDate;
  final String startedAt;
  final String? closedAt;
  final String status;
  final bool alreadySubmitted;

  bool get isActive => status == 'active';

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
