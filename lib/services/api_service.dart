import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:smart_classroom_new/models/assignment.dart';

import '../models/attendance.dart';
import '../models/course.dart';
import '../models/sensor_reading.dart';
import '../models/student.dart';


class ApiService {
  static const String baseUrl = 'http://192.168.1.136:8000';

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Login failed'));
    }

    return decoded as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
    String? studentId,
    String? department,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (studentId != null) 'studentId': studentId,
        if (department != null) 'department': department,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Registration failed'));
    }

    return decoded as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/admin/stats'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load admin stats: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid admin stats response');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> getAdminSensorOverview() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/admin/sensors/overview'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load sensor overview: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid sensor overview response');
    }

    return decoded;
  }

  Future<dynamic> addStudentToSession(
      String sessionId, String studentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/attendance/sessions/$sessionId/students'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'studentId': studentId}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('status')) {
        // Backend returned a status message (already exists / already enrolled)
        return decoded;
      }
      return AttendanceStudentRecord.fromJson(decoded as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      throw Exception("Student not found");
    } else {
      throw Exception("Failed to add student");
    }
  }

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    final uri = Uri.parse('$baseUrl/api/v1/users').replace(
      queryParameters: role == null ? null : {'role': role},
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load users: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid users response');
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createAdmin({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
    String? department,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/admin/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': 'admin',
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (department != null) 'department': department,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Registration failed'));
    }

    return decoded as Map<String, dynamic>;
  }

  Future<void> activateUser(String userId) async {
    final response = await http.patch(Uri.parse('$baseUrl/api/v1/users/$userId/activate'));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to activate user'));
    }
  }

  Future<List<Map<String, dynamic>>> getUsersExt({String? role, bool includeInactive = false}) async {
    final params = <String, String>{};
    if (role != null) params['role'] = role;
    if (includeInactive) params['includeInactive'] = 'true';
    final uri = Uri.parse('$baseUrl/api/v1/users').replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load users: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid users response');
    }

    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? department,
    String? phoneNumber,
    String? role,
    String? studentId,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (department != null) 'department': department,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (role != null) 'role': role,
        if (studentId != null) 'studentId': studentId,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to update user'));
    }

    return decoded as Map<String, dynamic>;
  }

  Future<void> deleteUser(String userId) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/v1/users/$userId'));
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to delete user'));
    }
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
    String? studentId,
    String? department,
  }) {
    return register(
      name: name,
      email: email,
      password: password,
      role: role,
      phoneNumber: phoneNumber,
      studentId: studentId,
      department: department,
    );
  }

  Future<List<SensorReading>> getLatestSensorReadings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/sensors/latest'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load sensor readings: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid sensor readings response');
    }

    return decoded
        .map((item) => SensorReading.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Course>> getCourses({String? userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses'),
      headers: {
        'Content-Type': 'application/json',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load courses: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid courses response');
    }

    return decoded
        .map((item) => Course.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Course> getCourse(String courseId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/courses/$courseId'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load course detail: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid course response');
    }

    return Course.fromJson(decoded);
  }

  Future<Map<String, dynamic>> enrollStudentInCourse({
    required String courseId,
    String? studentId,
    String? email,
  }) async {
    if ((studentId == null || studentId.isEmpty) &&
        (email == null || email.isEmpty)) {
      throw Exception('Student ID or email is required');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/students'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to enroll student'));
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return {'status': 'ok', 'data': decoded};
  }

  Future<Course> createCourse({
    required String courseName,
    int studentsCount = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? doctorId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/courses'),
      headers: {
        'Content-Type': 'application/json',
        if (userId != null && userId.isNotEmpty) 'X-User-Id': userId,
      },
      body: jsonEncode({
        'courseName': courseName,
        'studentsCount': studentsCount,
        'startDate': startDate?.toUtc().toIso8601String(),
        'endDate': endDate?.toUtc().toIso8601String(),
        if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_errorMessage(decoded, 'Failed to create course'));
    }

    return Course.fromJson(decoded as Map<String, dynamic>);
  }

  Future<Course> updateCourse({
    required String courseId,
    String? courseName,
    int? studentsCount,
    DateTime? startDate,
    DateTime? endDate,
    int? attendancePercent,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/courses/$courseId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (courseName != null) 'courseName': courseName,
        if (studentsCount != null) 'studentsCount': studentsCount,
        if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        if (attendancePercent != null) 'attendancePercent': attendancePercent,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to update course'));
    }

    return Course.fromJson(decoded as Map<String, dynamic>);
  }

  Future<void> deleteCourse(String courseId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/courses/$courseId'),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to delete course'));
    }
  }

  Future<CourseClass> addCourseClass({
    required String courseId,
    required String day,
    required String room,
    required String startTime,
    required String endTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/classes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'day': day,
        'room': room,
        'startTime': startTime,
        'endTime': endTime,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_errorMessage(decoded, 'Failed to add class'));
    }

    return CourseClass.fromJson(decoded as Map<String, dynamic>);
  }

  Future<void> deleteCourseClass(String courseId, String classId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/classes/$classId'),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to delete class'));
    }
  }

  Future<List<Student>> getCourseStudents(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/students'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load students: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid students response');
    }

    return decoded
        .map((item) => Student.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AttendanceSession>> getCourseSessions(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/sessions'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load sessions: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid sessions response');
    }

    return decoded
        .map((item) => AttendanceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSessionDetail> getAttendanceSession(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/attendance/sessions/$sessionId'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load attendance session: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid attendance session response');
    }

    return AttendanceSessionDetail.fromJson(decoded);
  }

  Future<AttendanceRecord> updateAttendanceRecord(
    String sessionId,
    String studentId,
    bool present,
  ) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/v1/attendance/sessions/$sessionId/records/$studentId',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'present': present}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to update attendance'));
    }

    return AttendanceRecord.fromJson(decoded as Map<String, dynamic>);
  }

  Future<AttendanceReport> getCourseAttendanceReport(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/attendance/report'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load attendance report: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid attendance report response');
    }

    return AttendanceReport.fromJson(decoded);
  }

  String _errorMessage(dynamic decoded, String fallback) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }

    return fallback;
  }

  Future<void> saveGrades(String courseId, List<Map<String, dynamic>> grades) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/grades'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'courseId': courseId,
        'grades': grades,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save grades');
    }
  }

  Future<List<Map<String, dynamic>>> getStudentGrades(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/grades/student/$studentId'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load grades');
  }

  Future<List<Map<String, dynamic>>> getCourseGrades(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/grades/course/$courseId'),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load course grades');
  }

  Future<Map<String, dynamic>> getStudentDashboard({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/me/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to load student dashboard'));
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid student dashboard response');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> getStudentCourses({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/me/courses'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to load student courses'));
    }
    if (decoded is! List) {
      throw Exception('Invalid student courses response');
    }
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getStudentSeats({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/me/seats'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to load student seats'));
    }
    if (decoded is! List) {
      throw Exception('Invalid student seats response');
    }
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createStudentSeat({
    required String userId,
    required String courseId,
    required String classId,
    required String seatNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/students/me/seats'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
      body: jsonEncode({
        'courseId': courseId,
        'classId': classId,
        'seatNumber': seatNumber,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 201) {
      throw Exception(_errorMessage(decoded, 'Failed to reserve seat'));
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid create seat response');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> updateStudentSeat({
    required String userId,
    required String reservationId,
    required String seatNumber,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/students/me/seats/$reservationId'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
      body: jsonEncode({'seatNumber': seatNumber}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to update seat'));
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid update seat response');
    }
    return decoded;
  }

  Future<void> cancelStudentSeat({
    required String userId,
    required String reservationId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/students/me/seats/$reservationId'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to cancel seat'));
    }
  }

  Future<List<Map<String, dynamic>>> getClassSeats({
    required String classId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/seats/class/$classId'),
      headers: {'Content-Type': 'application/json'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to load class seats'));
    }
    if (decoded is! List) return [];
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getGradeComponents(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/grade-components'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final components = decoded['components'];
        if (components is List) {
          return components.cast<Map<String, dynamic>>();
        }
      }
      return [];
    }
    throw Exception('Failed to load grade components: ${response.statusCode}');
  }

  Future<void> setGradeComponents(String courseId, List<Map<String, dynamic>> components) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/grade-components'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'components': components.map((c) => {
          'name': c['name'],
          'percentage': c['percentage'],
        }).toList(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set grade components');
    }
  }

  Future<void> saveGradesBulk(String courseId, List<Map<String, dynamic>> grades) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/grades/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'courseId': courseId,
        'grades': grades,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save grades');
    }
  }

  Future<Map<String, dynamic>> getStudentCourseGrade(String courseId, String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/grades/course/$courseId/student/$studentId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Invalid grade response');
    }
    throw Exception('Failed to load grade: ${response.statusCode}');
  }

  /// Fetch assignments for a student's course
  Future<List<Map<String, dynamic>>> getStudentCourseAssignments({
    required String userId,
    required String courseId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/me/courses/$courseId/assignments'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load assignments: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  /// Fetch announcements for a student's course
  Future<List<Map<String, dynamic>>> getStudentCourseAnnouncements({
    required String userId,
    required String courseId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/students/me/courses/$courseId/announcements'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load announcements: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<List<AttendanceSession>> getCourseSessionsByClass(String courseId, String classId) async {
    final uri = Uri.parse('$baseUrl/api/v1/courses/$courseId/sessions').replace(
      queryParameters: {'classId': classId},
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load sessions: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid sessions response');
    }
    return decoded
        .map((item) => AttendanceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> enrollStudentInCourseClass({
    required String courseId,
    required String classId,
    String? studentId,
    String? email,
  }) async {
    if ((studentId == null || studentId.isEmpty) &&
        (email == null || email.isEmpty)) {
      throw Exception('Student ID or email is required');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/students'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
        if (email != null && email.isNotEmpty) 'email': email,
        'classId': classId,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to enroll student'));
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('status')) {
      final status = decoded['status']?.toString() ?? '';
      if (status == 'already_exists') {
        throw Exception('Student already exists');
      } else if (status == 'already_enrolled') {
        throw Exception('Student is already enrolled in this course');
      }
    }
  }

  // ============================================================
  // ASSIGNMENT METHODS WITH BASE64 PDF SUPPORT
  // ============================================================

  Future<List<Assignment>> getClassAssignments(String courseId, String classId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/assignments/course/$courseId/class/$classId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded.map((item) => Assignment.fromJson(item as Map<String, dynamic>)).toList();
      }
    }
    throw Exception('Failed to load assignments: ${response.statusCode}');
  }

  /// Announcements API for doctors and classes
  Future<Map<String, dynamic>> createAnnouncement({
    required String userId,
    required String courseId,
    required String classId,
    required String title,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/announcements/course/$courseId/class/$classId'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
      body: jsonEncode({'title': title, if (message != null) 'message': message}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to create announcement'));
    }

    if (decoded is Map<String, dynamic>) return decoded;
    return {'status': 'ok', 'data': decoded};
  }

  Future<List<Map<String, dynamic>>> getClassAnnouncements({
    required String courseId,
    required String classId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/announcements/course/$courseId/class/$classId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load announcements: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> updateAnnouncement({
    required String announcementId,
    String? title,
    String? message,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/announcements/$announcementId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({if (title != null) 'title': title, if (message != null) 'message': message}),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to update announcement'));
    }
    return decoded as Map<String, dynamic>;
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/announcements/$announcementId'),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to delete announcement'));
    }
  }

  Future<Assignment> createAssignmentWithBase64({
    required String courseId,
    required String classId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? pdfBase64,
    double totalPoints = 100,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/assignments/course/$courseId/class/$classId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'dueDate': dueDate?.toUtc().toIso8601String(),
        'pdfBase64': pdfBase64,
        'totalPoints': totalPoints,
      }),
    );
    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return Assignment.fromJson(decoded as Map<String, dynamic>);
    }
    throw Exception('Failed to create assignment: ${response.statusCode}');
  }

  Future<Assignment> updateAssignmentWithBase64({
    required String assignmentId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? pdfBase64,
    double? totalPoints,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/assignments/$assignmentId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (dueDate != null) 'dueDate': dueDate.toUtc().toIso8601String(),
        if (pdfBase64 != null) 'pdfBase64': pdfBase64,
        if (totalPoints != null) 'totalPoints': totalPoints,
      }),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return Assignment.fromJson(decoded as Map<String, dynamic>);
    }
    throw Exception('Failed to update assignment: ${response.statusCode}');
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/assignments/$assignmentId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete assignment');
    }
  }

  Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // Legacy upload method - kept for compatibility but not recommended
  Future<String> uploadFile(File file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/upload/pdf'),
    );
    
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final decoded = jsonDecode(responseData);
    
    if (response.statusCode == 200) {
      return decoded['url'] as String;
    }
    
    throw Exception(decoded['detail'] ?? 'Failed to upload file');
  }
  Future<Map<String, String>> _getHeaders({String? token}) async {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  Future<List<Map<String, dynamic>>> getStudentNotifications({
    required String userId,
    int limit = 50,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/notifications/student/$userId?limit=$limit'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load notifications');
  }

  Future<int> getUnreadNotificationsCount({required String userId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/notifications/student/$userId/unread-count'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['unreadCount'] as int;
    }
    return 0;
  }

  Future<void> markNotificationRead({required String notificationId}) async {
    await http.patch(
      Uri.parse('$baseUrl/api/v1/notifications/$notificationId/read'),
      headers: await _getHeaders(),
    );
  }

  Future<void> markAllNotificationsRead({required String userId}) async {
    await http.patch(
      Uri.parse('$baseUrl/api/v1/notifications/student/$userId/read-all'),
      headers: await _getHeaders(),
    );

  }

  Future<Map<String, dynamic>> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String studentName,
    String? pdfBase64,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/assignments/$assignmentId/submissions'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'studentId': studentId,
        'studentName': studentName,
        if (pdfBase64 != null) 'pdfBase64': pdfBase64,
        if (comment != null) 'comment': comment,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(decoded, 'Failed to submit assignment'));
  }
  Future<List<dynamic>> getAssignmentSubmissions(String assignmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/assignments/$assignmentId/submissions'),
      headers: await _getHeaders(),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (decoded is List) return decoded;
      return decoded['submissions'] ?? [];
    }
    throw Exception(_errorMessage(decoded, 'Failed to load submissions'));
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/v1/assignments/submissions/$submissionId/grade'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'grade': grade,
        if (feedback != null) 'feedback': feedback,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(decoded, 'Failed to save grade'));
    }
  }

  Future<void> saveFcmToken({
    required String userId,
    required String token,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/users/$userId/fcm-token'),
        headers: await _getHeaders(),
        body: jsonEncode({'fcmToken': token}),
      );
    } catch (_) {
      // silently fail — not critical
    }
  }
  Future<List<Map<String, dynamic>>> getMissingSubmissions({
    required String courseId,
    String? classId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/assignments/course/$courseId/missing-submissions')
        .replace(queryParameters: classId != null ? {'classId': classId} : null);
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMissingGrades({
    required String courseId,
    String? classId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/grades/course/$courseId/missing')
        .replace(queryParameters: classId != null ? {'classId': classId} : null);
    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getCourseAttendanceReportData(String courseId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/courses/$courseId/attendance/report'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }
  Future<String> sendAiMessage({
    required String message,
    required Map<String, dynamic> context,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/ai/chat'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'message': message,
        'context': context,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String;
    }
    throw Exception('Failed to get AI response');
  }
  Future<void> clearFcmToken({required String userId}) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/v1/users/$userId/fcm-token'),
        headers: await _getHeaders(),
      );
    } catch (_) {}
  }
}
