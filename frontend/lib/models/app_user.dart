/// Represents the authenticated user: a student, Pusat Adab staff, lecturer,
/// or faculty registrar.
///
/// This model is populated after a successful login and stored inside
/// [AppController]. It is used throughout the app to display user info
/// and to determine which screens to show based on [role].
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.studentId,
    this.course,
    this.phoneNumber,
    this.currentSemester,
    this.personalAdvisor,
    this.address,
  });

  /// Database primary key for this user.
  final int id;

  /// Full name of the user.
  final String name;

  /// Login email address.
  final String email;

  /// Role determines access level: 'student', 'adab' (Pusat Adab staff),
  /// 'lecturer', or 'faculty_registrar'.
  final String role;

  /// University student ID (e.g. CB21110). Null for Pusat Adab accounts.
  final String? studentId;

  /// Student's programme/course name. Null for Pusat Adab accounts.
  final String? course;

  /// Contact phone number. Optional for all user types.
  final String? phoneNumber;

  /// Current semester number (e.g. '5'). Student-specific field.
  final String? currentSemester;

  /// Name of the student's personal academic advisor.
  final String? personalAdvisor;

  /// Home or current address. Optional for all user types.
  final String? address;

  // ── Computed properties ────────────────────────────────────────────────────

  bool get isPusatAdab => role == 'adab';
  bool get isTreasury => role == 'treasury';

  /// Returns true if this user is a lecturer.
  bool get isLecturer => role == 'lecturer';

  /// Returns true if this user is Faculty Registrar staff.
  bool get isFacultyRegistrar => role == 'faculty_registrar';

  // ── Factory constructor ────────────────────────────────────────────────────

  /// Creates an [AppUser] from the JSON map returned by the login endpoint.
  /// Fields that may be null in the database are cast with 'as String?'.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      studentId: json['student_id'] as String?,
      course: json['course'] as String?,
      phoneNumber: json['phone_number'] as String?,
      currentSemester: json['current_semester'] as String?,
      personalAdvisor: json['personal_advisor'] as String?,
      address: json['address'] as String?,
    );
  }

  // ── copyWith ───────────────────────────────────────────────────────────────

  /// Returns a new [AppUser] with the specified fields replaced.
  /// Only editable profile fields are included here — id, name, email,
  /// role, studentId, and course cannot be changed from the app.
  AppUser copyWith({
    String? phoneNumber,
    String? currentSemester,
    String? personalAdvisor,
    String? address,
  }) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      studentId: studentId,
      course: course,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      currentSemester: currentSemester ?? this.currentSemester,
      personalAdvisor: personalAdvisor ?? this.personalAdvisor,
      address: address ?? this.address,
    );
  }
}
