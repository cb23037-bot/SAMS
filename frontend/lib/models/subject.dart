class SectionOption {
  final String section;
  final String? instructor;
  final String? schedule;

  SectionOption({
    required this.section,
    this.instructor,
    this.schedule,
  });

  factory SectionOption.fromJson(Map<String, dynamic> json) {
    return SectionOption(
      section: json['section'] as String,
      instructor: json['lecturer'] as String? ?? json['instructor'] as String?,
      schedule: json['schedule'] as String?,
    );
  }
}

class Subject {
  final int id;
  final String name;
  final String code;
  final int creditHours;
  final String? lectureSection;
  final String? labSection;
  final String? lecturer;
  final String? labInstructor;
  final String? lectureSchedule;
  final String? labSchedule;
  final List<SectionOption> lectureSections;
  final List<SectionOption> labSections;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.creditHours,
    this.lectureSection,
    this.labSection,
    this.lecturer,
    this.labInstructor,
    this.lectureSchedule,
    this.labSchedule,
    this.lectureSections = const [],
    this.labSections = const [],
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    final lectureSectionsJson = json['lecture_sections'];
    final labSectionsJson = json['lab_sections'];

    final lectureSections = <SectionOption>[];
    final labSections = <SectionOption>[];

    if (lectureSectionsJson is List) {
      lectureSections.addAll(lectureSectionsJson
          .whereType<Map<String, dynamic>>()
          .map(SectionOption.fromJson));
    } else if (json['lecture_section'] != null || json['lecturer'] != null || json['lecture_schedule'] != null) {
      lectureSections.add(SectionOption(
        section: json['lecture_section'] as String? ?? '01',
        instructor: json['lecturer'] as String?,
        schedule: json['lecture_schedule'] as String?,
      ));
    }

    if (labSectionsJson is List) {
      labSections.addAll(labSectionsJson
          .whereType<Map<String, dynamic>>()
          .map(SectionOption.fromJson));
    } else if (json['lab_section'] != null || json['lab_instructor'] != null || json['lab_schedule'] != null) {
      labSections.add(SectionOption(
        section: json['lab_section'] as String? ?? '01A',
        instructor: json['lab_instructor'] as String?,
        schedule: json['lab_schedule'] as String?,
      ));
    }

    return Subject(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      creditHours: json['credit_hours'] as int,
      lectureSection: json['lecture_section'] as String?,
      labSection: json['lab_section'] as String?,
      lecturer: json['lecturer'] as String?,
      labInstructor: json['lab_instructor'] as String?,
      lectureSchedule: json['lecture_schedule'] as String?,
      labSchedule: json['lab_schedule'] as String?,
      lectureSections: lectureSections,
      labSections: labSections,
    );
  }
}