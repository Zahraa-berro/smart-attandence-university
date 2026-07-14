import 'package:flutter/foundation.dart';

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  final Map<String, List<Map<String, dynamic>>> _baseStudents = {
    "Mobile Application Development": [
      {"id": "20220145", "name": "Ali Hassan", "image": "assets/students/ali.jpg"},
      {"id": "20220188", "name": "Sara Ali", "image": "assets/students/sara.jpg"},
      {"id": "20220210", "name": "Omar Khaled", "image": "assets/students/omar.jpg"},
      {"id": "20220234", "name": "Nour Tarek", "image": "assets/students/nour.jpg"},
      {"id": "20220267", "name": "Youssef Adel", "image": "assets/students/youssef.jpg"},
    ],
  };

  final Map<String, List<Map<String, dynamic>>> _extraStudents = {};
  final Map<String, Map<String, bool>> _attendance = {};

  List<Map<String, dynamic>> getStudents(String courseName) {
    final base = List<Map<String, dynamic>>.from(_baseStudents[courseName] ?? []);
    final extra = _extraStudents[courseName] ?? [];
    return [...base, ...extra];
  }

  void addStudent(String courseName, Map<String, dynamic> student) {
    _extraStudents.putIfAbsent(courseName, () => []);
    _extraStudents[courseName]!.add(student);
    notifyListeners(); // ← notify grades screen
  }

  String _key(String courseName, DateTime date) =>
      "$courseName||${date.year.toString().padLeft(4, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.day.toString().padLeft(2, '0')}";

  Map<String, bool> getAttendance(String courseName, DateTime date) {
    final key = _key(courseName, date);
    final students = getStudents(courseName);
    final stored = _attendance[key] ?? {};
    return {
      for (final s in students)
        s["id"] as String: stored[s["id"] as String] ?? false,
    };
  }

  void setPresent(String courseName, DateTime date, String studentId, bool val) {
    final key = _key(courseName, date);
    _attendance.putIfAbsent(key, () => {});
    _attendance[key]![studentId] = val;
    notifyListeners();
  }

  Map<String, int>? getSummary(String courseName, DateTime date) {
    final key = _key(courseName, date);
    if (!_attendance.containsKey(key)) return null;
    final data = _attendance[key]!;
    final present = data.values.where((v) => v).length;
    final total = getStudents(courseName).length;
    return {"present": present, "total": total};
  }
}