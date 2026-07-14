import 'student.dart';

class AttendanceSession {
  final String id;
  final String sessionId;
  final String courseId;
  final String classId;
  final DateTime date;
  final String day;
  final String room;
  final String startTime;
  final String endTime;
  final String status;

  AttendanceSession({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.classId,
    required this.date,
    required this.day,
    required this.room,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['_id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      classId: json['classId']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      day: json['day']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class AttendanceRecord {
  final String id;
  final String recordId;
  final String sessionId;
  final String courseId;
  final String studentId;
  final bool present;
  final String? detectedBy;

  AttendanceRecord({
    required this.id,
    required this.recordId,
    required this.sessionId,
    required this.courseId,
    required this.studentId,
    required this.present,
    this.detectedBy,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['_id']?.toString() ?? '',
      recordId: json['recordId']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      courseId: json['courseId']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      present: json['present'] == true,
      detectedBy: json['detectedBy']?.toString(),
    );
  }
}

class AttendanceStudentRecord {
  final Student student;
  final AttendanceRecord? record;

  AttendanceStudentRecord({required this.student, required this.record});

  factory AttendanceStudentRecord.fromJson(Map<String, dynamic> json) {
    final studentJson = json['student'] as Map<String, dynamic>? ?? {};
    final recordJson = json['record'];
    return AttendanceStudentRecord(
      student: Student.fromJson(studentJson),
      record: recordJson is Map<String, dynamic>
          ? AttendanceRecord.fromJson(recordJson)
          : null,
    );
  }
}

class AttendanceSessionDetail {
  final AttendanceSession session;
  final List<AttendanceStudentRecord> records;

  AttendanceSessionDetail({required this.session, required this.records});

  factory AttendanceSessionDetail.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'];
    return AttendanceSessionDetail(
      session: AttendanceSession.fromJson(
        json['session'] as Map<String, dynamic>? ?? {},
      ),
      records: recordsJson is List
          ? recordsJson
                .map(
                  (item) => AttendanceStudentRecord.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList()
          : [],
    );
  }
}

class AttendanceStudentStat {
  final String studentId;
  final String name;
  final int present;
  final int absent;

  AttendanceStudentStat({
    required this.studentId,
    required this.name,
    required this.present,
    required this.absent,
  });

  factory AttendanceStudentStat.fromJson(Map<String, dynamic> json) {
    return AttendanceStudentStat(
      studentId: json['studentId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceReport {
  final String courseId;
  final int totalSessions;
  final int conductedCount;
  final int totalStudents;
  final int totalPresent;
  final int totalAbsent;
  final int attendancePercentage;
  final List<AttendanceStudentStat> students;

  AttendanceReport({
    required this.courseId,
    required this.totalSessions,
    required this.conductedCount,
    required this.totalStudents,
    required this.totalPresent,
    required this.totalAbsent,
    required this.attendancePercentage,
    required this.students,
  });

  factory AttendanceReport.fromJson(Map<String, dynamic> json) {
    final studentsJson = json['students'];
    return AttendanceReport(
      courseId: json['courseId']?.toString() ?? '',
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      conductedCount: (json['conductedCount'] as num?)?.toInt() ?? 0,
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      totalPresent: (json['totalPresent'] as num?)?.toInt() ?? 0,
      totalAbsent: (json['totalAbsent'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendancePercentage'] as num?)?.toInt() ?? 0,
      students: studentsJson is List
          ? studentsJson
                .map(
                  (item) => AttendanceStudentStat.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList()
          : [],
    );
  }
}