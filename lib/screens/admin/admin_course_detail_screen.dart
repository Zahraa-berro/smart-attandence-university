import 'package:flutter/material.dart';
import 'package:smart_classroom_new/models/attendance.dart';
import 'package:smart_classroom_new/models/course.dart';
import 'package:smart_classroom_new/models/student.dart';
import 'package:smart_classroom_new/services/api_service.dart';

class AdminCourseDetailScreen extends StatefulWidget {
  final String courseId;

  const AdminCourseDetailScreen({super.key, required this.courseId});

  @override
  State<AdminCourseDetailScreen> createState() => _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _studentIdController = TextEditingController();

  Course? _course;
  List<Student> _students = [];
  List<AttendanceSession> _sessions = [];
  AttendanceReport? _attendanceReport;
  bool _isLoading = true;
  String? _errorMessage;

  // Design tokens
  static const Color _brand = Color(0xFF1D9E75);
  static const Color _brandLight = Color(0xFF5DCAA5);
  static const Color _danger = Color(0xFFD85A30);
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);
  static const Color _border = Color(0xFFE7E5E0);

  Widget _statCard({required IconData icon, required String value, required String label, required Color accent, VoidCallback? onTap}) {
    final card = Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0,6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: _inkMuted)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }

  Widget _surfaceCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0,6))],
      ),
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCourseData();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final course = await _apiService.getCourse(widget.courseId);
      final students = await _apiService.getCourseStudents(widget.courseId);
      final sessions = await _apiService.getCourseSessions(widget.courseId);
      final attendanceReport = await _apiService.getCourseAttendanceReport(widget.courseId);

      if (!mounted) return;

      setState(() {
        _course = course;
        _students = students;
        _sessions = sessions;
        _attendanceReport = attendanceReport;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enrollStudent() async {
    if (_studentIdController.text.trim().isEmpty) {
      _showMessage('Enter student ID to enroll');
      return;
    }

    try {
      final resp = await _apiService.enrollStudentInCourse(
        courseId: widget.courseId,
        studentId: _studentIdController.text.trim(),
        email: null,
      );

      final status = resp['status']?.toString() ?? '';
      if (status == 'already_enrolled') {
        _showMessage('Student is already enrolled in this course', isError: true);
      } else if (status == 'already_exists') {
        _showMessage('Student record already exists for this course', isError: true);
      } else {
        _studentIdController.clear();
        _showMessage('Student enrolled successfully');
        await _loadCourseData();
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int get _computedAttendancePercent {
    if (_attendanceReport != null) {
      return _attendanceReport!.attendancePercentage;
    }
    return _course?.attendancePercent ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // Gradient header
                    Container(
                      height: 220,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5DCAA5), Color(0xFF9FE1CB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          // Top bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Course Analytics', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                                  onPressed: _loadCourseData,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // White sheet
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                              ),
                              child: Column(
                                children: [
                                  Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2))),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_course != null) ...[
                                            _surfaceCard(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(_course!.courseName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
                                                  const SizedBox(height: 6),
                                                  Text('Code: ${_course!.courseCode ?? 'N/A'}', style: const TextStyle(color: _inkMuted)),
                                                  const SizedBox(height: 6),
                                                  Text('Dates: ${_formatDate(_course!.startDate)} — ${_formatDate(_course!.endDate)}', style: const TextStyle(color: _inkMuted)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),

                                            // Stats
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: [
                                                _statCard(icon: Icons.group_rounded, value: '${_course!.studentsCount}', label: 'Enrolled', accent: _brand),
                                                _statCard(icon: Icons.bar_chart_rounded, value: '$_computedAttendancePercent%', label: 'Attendance', accent: _brandLight),
                                                _statCard(icon: Icons.schedule_rounded, value: '${_course!.classesCount}', label: 'Schedule', accent: const Color(0xFF5B8DEF)),
                                                _statCard(icon: Icons.event_available_rounded, value: '${_sessions.length}', label: 'Sessions', accent: const Color(0xFFEF9F27)),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            _surfaceCard(child: _buildEnrollmentForm(), padding: const EdgeInsets.all(14)),
                                            const SizedBox(height: 14),
                                            _surfaceCard(child: _buildAttendanceSummary(), padding: const EdgeInsets.all(14)),
                                            const SizedBox(height: 14),
                                            _surfaceCard(child: _buildScheduleSection(), padding: const EdgeInsets.all(14)),
                                            const SizedBox(height: 14),
                                            _surfaceCard(child: _buildStudentSection(), padding: const EdgeInsets.all(14)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCourseHeader() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _course!.courseName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Code: ${_course!.courseCode ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Department: ${_course!.department} • ${_course!.semester}'),
            const SizedBox(height: 4),
            Text('Dates: ${_formatDate(_course!.startDate)} — ${_formatDate(_course!.endDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetrics() {
    final metrics = [
      _MetricCardData(label: 'Enrolled', value: '${_course!.studentsCount}'),
      _MetricCardData(label: 'Attendance', value: '$_computedAttendancePercent%'),
      _MetricCardData(label: 'Schedule', value: '${_course!.classesCount}'),
      _MetricCardData(label: 'Sessions', value: '${_sessions.length}'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map(
            (metric) => Container(
              width: (MediaQuery.of(context).size.width - 60) / 2,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.withOpacity(0.16)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(metric.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEnrollmentForm() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enroll Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
                hintText: 'e.g. 202610001',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enrollStudent,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D9E75)),
                child: const Text('Enroll Student'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_attendanceReport == null)
              const Text('No attendance data available yet.')
            else ...[
              _buildDetailRow('Total Students', '${_attendanceReport!.totalStudents}'),
              _buildDetailRow('Conducted Sessions', '${_attendanceReport!.conductedCount}/${_attendanceReport!.totalSessions}'),
              _buildDetailRow('Present', '${_attendanceReport!.totalPresent}'),
              _buildDetailRow('Absent', '${_attendanceReport!.totalAbsent}'),
              const SizedBox(height: 12),
              const Text('Top student attendance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_attendanceReport!.students.isEmpty)
                const Text('No student attendance breakdown available.')
              else
                Column(
                  children: _attendanceReport!.students
                      .take(4)
                      .map(
                        (student) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(student.name),
                          subtitle: Text('Present: ${student.present}  Absent: ${student.absent}'),
                        ),
                      )
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Course Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_course!.classes.isEmpty)
              const Text('No scheduled classes available.')
            else
              Column(
                children: _course!.classes.map((classItem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${classItem.day} • ${classItem.room}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text('${classItem.startTime} — ${classItem.endTime}', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enrolled Students', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_students.isEmpty)
              const Text('No enrolled students are currently available.')
            else
              Column(
                children: _students.map((student) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(student.name),
                    subtitle: Text('${student.studentId} • ${student.email}'),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  final String label;
  final String value;

  _MetricCardData({required this.label, required this.value});
}