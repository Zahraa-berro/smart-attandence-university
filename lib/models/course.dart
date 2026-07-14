class CourseClass {
  final String? classId;
  final String day;
  final String room;
  final String startTime;
  final String endTime;
  List<Map<String, dynamic>>? students;

  CourseClass({
    this.classId,
    required this.day,
    required this.room,
    required this.startTime,
    required this.endTime,
    this.students,
  });

  factory CourseClass.fromJson(Map<String, dynamic> json) {
    return CourseClass(
      classId: json['classId'] as String?,
      day: json['day'] as String? ?? '',
      room: json['room'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      students: json['students'] as List<Map<String, dynamic>>?,
    );
  }
}

class Course {
  final String id;
  final String courseId;
  final String courseName;
  final String? courseCode;
  final String doctorId;
  final String department;
  final String semester;
  final DateTime? startDate;
  final DateTime? endDate;
  final int attendancePercent;
  final int studentsCount;
  final int classesCount;
  final DateTime createdAt;
  final List<CourseClass> classes;

  String get title => courseName;
  int get students => studentsCount;
  int get attendance => attendancePercent;
  bool get hasDates => startDate != null && endDate != null;

  Course({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.courseCode,
    required this.doctorId,
    required this.department,
    required this.semester,
    this.startDate,
    this.endDate,
    required this.attendancePercent,
    required this.studentsCount,
    required this.classesCount,
    required this.createdAt,
    required this.classes,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id'] as String,
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      courseCode: json['courseCode'] as String?,
      doctorId: json['doctorId'] as String,
      department: json['department'] as String,
      semester: json['semester'] as String,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      attendancePercent: (json['attendancePercent'] as num?)?.toInt() ?? 0,
      studentsCount: (json['studentsCount'] as num?)?.toInt() ?? 0,
      classesCount: (json['classesCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      classes: (json['schedule'] as List? ?? [])
          .map((item) => CourseClass.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}