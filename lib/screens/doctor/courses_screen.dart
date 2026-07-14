import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'air_quality_screen.dart';
import 'course_detail_screen.dart';
import 'notification_screen.dart';
import 'announcements_screen.dart';
import '../../models/course.dart';
import '../../services/api_service.dart';
import 'grades_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();
}

class CoursesScreen extends StatefulWidget {
  final String userId;

  const CoursesScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  final ApiService _apiService = ApiService();
  bool _isLoadingCourses = true;
  String? _coursesError;
  bool _isRefreshing = false;

  final List<Course> _courses = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _loadCourses();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshCourses() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    await _loadCourses();
    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoadingCourses = true;
      _coursesError = null;
    });

    try {
      final courses = await _apiService.getCourses(userId: widget.userId);
      if (!mounted) return;

      setState(() {
        _courses
          ..clear()
          ..addAll(courses);
        _isLoadingCourses = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingCourses = false;
        _coursesError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int get _totalStudents => _courses.fold(0, (sum, c) => sum + c.students);

  double get _avgAttendance => _courses.isEmpty
      ? 0
      : _courses.fold(0, (sum, c) => sum + c.attendance) / _courses.length;

  Color _attendanceColor(int pct) {
    if (pct >= 85) return const Color(0xFF1D9E75);
    if (pct >= 70) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return "Not set";
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return "${d.day} ${months[d.month]} ${d.year}";
  }

  Future<DateTime?> _pickDate(
      BuildContext context,
      DateTime? initial,
      DateTime? firstDate,
      DateTime? lastDate,
      ) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2035),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D9E75),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );

  String? _findTimeConflict(
      String day,
      String room,
      TimeOfDay start,
      TimeOfDay end, {
        String? excludeClassId,
      }) {
    final newStart = start.hour * 60 + start.minute;
    final newEnd   = end.hour   * 60 + end.minute;

    if (newEnd <= newStart) return null;

    for (final course in _courses) {
      for (final cls in course.classes) {
        if (cls.day != day) continue;
        if (cls.room != room) continue;
        if (excludeClassId != null && cls.classId == excludeClassId) continue;

        int parseTime(String t) {
          final parts = t.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }

        final exStart = parseTime(cls.startTime);
        final exEnd   = parseTime(cls.endTime);

        if (newStart < exEnd && exStart < newEnd) {
          return '${course.title} · ${cls.room}  '
              '(${cls.startTime}–${cls.endTime})';
        }
      }
    }
    return null;
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFD85A30), size: 22),
            SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF888780),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD85A30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openAIChatbot() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => _AIChatScreen(
          courses: _courses,
          userId: widget.userId,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showAddCourseSheet() {
    final titleCtrl    = TextEditingController();
    final studentsCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool      isSaving  = false;
    String?   errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _BottomSheet(
          title: "Add New Course",
          icon: Icons.menu_book_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel("Course Title"),
              const SizedBox(height: 8),
              _sheetField(titleCtrl, "e.g. Software Engineering", Icons.title),
              const SizedBox(height: 16),
              _sheetLabel("Number of Students"),
              const SizedBox(height: 8),
              _sheetField(
                studentsCtrl,
                "e.g. 35",
                Icons.people_alt_outlined,
                type: TextInputType.number,
              ),
              const SizedBox(height: 18),
              _sheetLabel("Semester Period"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      label: "Start Date",
                      date: startDate,
                      onTap: () async {
                        final picked = await _pickDate(ctx, startDate, null, endDate);
                        if (picked != null) setLocal(() => startDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateTile(
                      label: "End Date",
                      date: endDate,
                      onTap: () async {
                        final picked = await _pickDate(ctx, endDate, startDate, null);
                        if (picked != null) setLocal(() => endDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (startDate != null && endDate != null) ...[
                const SizedBox(height: 10),
                _semesterPreview(startDate!, endDate!),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 14),
                _errorBox(errorText!),
              ],
              const SizedBox(height: 28),
              _sheetButton(isSaving ? "Saving..." : "Add Course", () async {
                if (isSaving) return;
                final title    = titleCtrl.text.trim();
                final students = int.tryParse(studentsCtrl.text.trim()) ?? 0;
                if (title.isEmpty) {
                  setLocal(() => errorText = "Course title is required.");
                  return;
                }
                setLocal(() {
                  isSaving  = true;
                  errorText = null;
                });
                try {
                  await _apiService.createCourse(
                    courseName:    title,
                    studentsCount: students,
                    startDate:     startDate,
                    endDate:       endDate,
                    userId:        widget.userId,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadCourses();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Course added successfully."),
                      backgroundColor: Color(0xFF1D9E75),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  setLocal(() {
                    isSaving  = false;
                    errorText = error.toString().replaceFirst('Exception: ', '');
                  });
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditCourseSheet(Course course) {
    final titleCtrl    = TextEditingController(text: course.title);
    final studentsCtrl = TextEditingController(text: course.students.toString());
    DateTime? startDate = course.startDate;
    DateTime? endDate   = course.endDate;
    bool      isSaving  = false;
    String?   errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _BottomSheet(
          title: "Edit Course",
          icon: Icons.edit_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel("Course Title"),
              const SizedBox(height: 8),
              _sheetField(titleCtrl, "e.g. Software Engineering", Icons.title),
              const SizedBox(height: 16),
              _sheetLabel("Number of Students"),
              const SizedBox(height: 8),
              _sheetField(
                studentsCtrl,
                "e.g. 35",
                Icons.people_alt_outlined,
                type: TextInputType.number,
              ),
              const SizedBox(height: 18),
              _sheetLabel("Semester Period"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      label: "Start Date",
                      date: startDate,
                      onTap: () async {
                        final picked = await _pickDate(ctx, startDate, null, endDate);
                        if (picked != null) setLocal(() => startDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateTile(
                      label: "End Date",
                      date: endDate,
                      onTap: () async {
                        final picked = await _pickDate(ctx, endDate, startDate, null);
                        if (picked != null) setLocal(() => endDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (startDate != null && endDate != null) ...[
                const SizedBox(height: 10),
                _semesterPreview(startDate!, endDate!),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 14),
                _errorBox(errorText!),
              ],
              const SizedBox(height: 28),
              _sheetButton(isSaving ? "Saving..." : "Save Changes", () async {
                if (isSaving) return;
                final title    = titleCtrl.text.trim();
                final students = int.tryParse(studentsCtrl.text.trim()) ?? 0;
                if (title.isEmpty) {
                  setLocal(() => errorText = "Course title is required.");
                  return;
                }
                setLocal(() {
                  isSaving  = true;
                  errorText = null;
                });
                try {
                  await _apiService.updateCourse(
                    courseId:      course.courseId,
                    courseName:    title,
                    studentsCount: students,
                    startDate:     startDate,
                    endDate:       endDate,
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadCourses();
                } catch (error) {
                  if (!mounted) return;
                  setLocal(() {
                    isSaving  = false;
                    errorText = error.toString().replaceFirst('Exception: ', '');
                  });
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCourse(Course course) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFD85A30), size: 22),
            SizedBox(width: 8),
            Text(
              "Delete Course",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${course.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF888780), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _apiService.deleteCourse(course.courseId);
                if (!mounted) return;
                await _loadCourses();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Course deleted successfully."),
                    backgroundColor: Color(0xFF1D9E75),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: const Color(0xFFD85A30),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD85A30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddClassSheet(Course course) {
    final roomCtrl    = TextEditingController();
    String?   selectedDay;
    TimeOfDay startTime = const TimeOfDay(hour: 8,  minute: 0);
    TimeOfDay endTime   = const TimeOfDay(hour: 10, minute: 0);
    bool      isSaving  = false;
    String?   errorText;
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _BottomSheet(
          title: "Add Class",
          subtitle: course.title,
          icon: Icons.class_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetLabel("Day"),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days.map((d) {
                  final selected = selectedDay == d;
                  return GestureDetector(
                    onTap: () => setLocal(() => selectedDay = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF1D9E75) : const Color(0xFFF1EFE8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : const Color(0xFF444441),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _sheetLabel("Room / Hall"),
              const SizedBox(height: 8),
              _sheetField(roomCtrl, "e.g. C1.3", Icons.meeting_room_outlined),
              const SizedBox(height: 18),
              _sheetLabel("Time"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      label: "Start",
                      time: startTime,
                      onTap: () async {
                        final picked = await showTimePicker(context: ctx, initialTime: startTime);
                        if (picked != null) setLocal(() => startTime = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeTile(
                      label: "End",
                      time: endTime,
                      onTap: () async {
                        final picked = await showTimePicker(context: ctx, initialTime: endTime);
                        if (picked != null) setLocal(() => endTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              if (selectedDay != null && roomCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(builder: (_) {
                  final room = roomCtrl.text.trim();
                  final conflict = _findTimeConflict(selectedDay!, room, startTime, endTime);
                  if (conflict == null) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D9E75).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.30)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF1D9E75)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Room is available at this time",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1D9E75),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return _conflictBanner(conflict);
                }),
              ],
              if (selectedDay != null && course.hasDates) ...[
                const SizedBox(height: 10),
                _sessionCountPreview(selectedDay!, course.startDate!, course.endDate!),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 14),
                _errorBox(errorText!),
              ],
              const SizedBox(height: 28),
              _sheetButton(isSaving ? "Saving..." : "Add Class", () async {
                if (isSaving) return;
                if (selectedDay == null || roomCtrl.text.trim().isEmpty) {
                  setLocal(() => errorText = "Day and room are required.");
                  return;
                }
                final endMinutes   = endTime.hour   * 60 + endTime.minute;
                final startMinutes = startTime.hour * 60 + startTime.minute;
                if (endMinutes <= startMinutes) {
                  setLocal(() => errorText = "End time must be after start time.");
                  return;
                }
                final room = roomCtrl.text.trim();
                final conflict = _findTimeConflict(selectedDay!, room, startTime, endTime);
                if (conflict != null) {
                  setLocal(() => errorText =
                  "⚠️ Time conflict in room '$room' with:\n$conflict\n\nPlease choose a different day, room, or time slot.");
                  return;
                }
                final fmt = (TimeOfDay t) =>
                "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
                setLocal(() {
                  isSaving  = true;
                  errorText = null;
                });
                try {
                  await _apiService.addCourseClass(
                    courseId:  course.courseId,
                    day:       selectedDay!,
                    room:      room,
                    startTime: fmt(startTime),
                    endTime:   fmt(endTime),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadCourses();
                } catch (error) {
                  if (!mounted) return;
                  setLocal(() {
                    isSaving  = false;
                    errorText = error.toString().replaceFirst('Exception: ', '');
                  });
                }
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF444441),
      letterSpacing: 0.2,
    ),
  );

  Widget _sheetField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType type = TextInputType.text,
      }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF888780)),
          filled: true,
          fillColor: const Color(0xFFF1EFE8),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
        ),
      );

  Widget _dateTile({required String label, required DateTime? date, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EFE8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF888780)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888780), fontWeight: FontWeight.w500)),
                  Text(
                    date != null ? _formatDate(date) : "Tap to set",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: date != null ? const Color(0xFF2C2C2A) : const Color(0xFFB4B2A9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _timeTile({required String label, required TimeOfDay time, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EFE8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF888780)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888780), fontWeight: FontWeight.w500)),
                  Text(
                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2C2C2A)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _semesterPreview(DateTime start, DateTime end) {
    final days  = end.difference(start).inDays + 1;
    final weeks = (days / 7).floor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D9E75).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1D9E75)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${_formatDate(start)}  →  ${_formatDate(end)}   ·   ~$weeks weeks",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D9E75)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCountPreview(String day, DateTime start, DateTime end) {
    final count = _countSessions(day, start, end);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8DEF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5B8DEF).withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF5B8DEF)),
          const SizedBox(width: 8),
          Text(
            "$count $day sessions will be auto-generated",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B8DEF)),
          ),
        ],
      ),
    );
  }

  Widget _conflictBanner(String conflictDescription) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFD85A30).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFD85A30).withOpacity(0.30)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD85A30)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Room time conflict detected",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD85A30)),
              ),
              const SizedBox(height: 2),
              Text(
                conflictDescription,
                style: const TextStyle(fontSize: 11, color: Color(0xFFD85A30), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _errorBox(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFD85A30).withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFFD85A30), fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  int _countSessions(String day, DateTime start, DateTime end) {
    const dayMap = {
      "Mon": DateTime.monday,
      "Tue": DateTime.tuesday,
      "Wed": DateTime.wednesday,
      "Thu": DateTime.thursday,
      "Fri": DateTime.friday,
      "Sat": DateTime.saturday,
      "Sun": DateTime.sunday,
    };
    final target = dayMap[day];
    if (target == null) return 0;
    int      count   = 0;
    DateTime current = start;
    while (!current.isAfter(end)) {
      if (current.weekday == target) count++;
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  Widget _sheetButton(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D9E75).withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5DCAA5),
                  Color(0xFF9FE1CB),
                  Color(0xFFF0997B),
                  Color(0xFFD85A30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.person_rounded, size: 22, color: Color(0xFF1D9E75)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Good morning, Doctor",
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "Faculty of Engineering",
                              style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _refreshCourses,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _isRefreshing
                                  ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                                ),
                              )
                                  : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _confirmLogout,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _openAIChatbot,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.smart_toy_rounded, color: Color(0xFF1D9E75), size: 22),
                                Positioned(
                                  top: 9,
                                  right: 9,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1D9E75),
                                      shape: BoxShape.circle,
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
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _statPill(Icons.menu_book_rounded, "${_courses.length}", "Courses"),
                        const SizedBox(width: 10),
                        _statPill(Icons.people_alt_outlined, "$_totalStudents", "Students"),
                        const SizedBox(width: 10),
                        _statPill(Icons.bar_chart_rounded, "${_avgAttendance.toStringAsFixed(0)}%", "Avg Attend."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _airQualityShortcut(),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F7F4),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD3D1C7),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Active Courses",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _showAddCourseSheet,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1D9E75).withOpacity(0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                            SizedBox(width: 5),
                                            Text(
                                              "Add Course",
                                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(child: _coursesBody()),
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
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _airQualityShortcut() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AirQualityScreen()));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.air_rounded, color: Color(0xFF1D9E75), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("IoT Air Quality", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text("View live classroom sensor data", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coursesBody() {
    if (_isLoadingCourses) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1D9E75)));
    }
    if (_coursesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFD85A30), size: 42),
              const SizedBox(height: 12),
              Text(
                _coursesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5F5E5A), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              TextButton.icon(onPressed: _loadCourses, icon: const Icon(Icons.refresh_rounded), label: const Text("Retry")),
            ],
          ),
        ),
      );
    }
    if (_courses.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: _courses.length,
      itemBuilder: (_, i) => _courseCard(_courses[i]),
    );
  }

  Widget _courseCard(Course course) {
    final color = _attendanceColor(course.attendance);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, animation, __) => CourseDetailScreen(course: course),
                    transitionsBuilder: (_, animation, __, child) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                    transitionDuration: const Duration(milliseconds: 380),
                  ),
                );
                if (result == true && mounted) await _loadCourses();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${course.attendance}%",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _showEditCourseSheet(course);
                            else if (value == 'delete') _confirmDeleteCourse(course);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.white,
                          elevation: 4,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFFB4B2A9)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 16, color: Color(0xFF1D9E75)),
                                  SizedBox(width: 10),
                                  Text("Edit Course", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFD85A30)),
                                  SizedBox(width: 10),
                                  Text("Delete Course", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFD85A30))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF888780)),
                        const SizedBox(width: 5),
                        Text("${course.students} Students", style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                        const SizedBox(width: 16),
                        const Icon(Icons.class_outlined, size: 14, color: Color(0xFF888780)),
                        const SizedBox(width: 5),
                        Text("${course.classes.length} Classes", style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                      ],
                    ),
                    if (course.hasDates) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFF5B8DEF)),
                          const SizedBox(width: 5),
                          Text(
                            "${_formatDate(course.startDate)}  →  ${_formatDate(course.endDate)}",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5B8DEF), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Builder(builder: (_) {
                      if (!course.hasDates || course.classes.isEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0,
                            minHeight: 5,
                            backgroundColor: Color(0xFFF1EFE8),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B8DEF)),
                          ),
                        );
                      }
                      final today = DateTime.now();
                      final totalSessions = course.classes.fold<int>(
                        0, (sum, c) => sum + _countSessions(c.day, course.startDate!, course.endDate!),
                      );
                      final completedSessions = course.classes.fold<int>(0, (sum, c) {
                        const dayMap = {
                          "Mon": DateTime.monday, "Tue": DateTime.tuesday,
                          "Wed": DateTime.wednesday, "Thu": DateTime.thursday,
                          "Fri": DateTime.friday, "Sat": DateTime.saturday, "Sun": DateTime.sunday,
                        };
                        final target = dayMap[c.day];
                        if (target == null) return sum;
                        int count = 0;
                        DateTime current = course.startDate!;
                        while (!current.isAfter(course.endDate!) && !current.isAfter(today)) {
                          if (current.weekday == target) count++;
                          current = current.add(const Duration(days: 1));
                        }
                        return sum + count;
                      });
                      final progress = totalSessions == 0 ? 0.0 : completedSessions / totalSessions;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF1EFE8),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B8DEF)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$completedSessions / $totalSessions sessions done",
                            style: const TextStyle(fontSize: 10, color: Color(0xFF5B8DEF), fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }),
                    if (course.classes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...course.classes.map(
                            (c) => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GradesScreen(
                                  courseTitle: course.title,
                                  section: c.day,
                                  courseId: course.courseId,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D9E75).withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.day,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D9E75)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${c.room}  ·  ${c.startTime} – ${c.endTime}",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF5F5E5A)),
                                  ),
                                ),
                                if (course.hasDates)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5B8DEF).withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${_countSessions(c.day, course.startDate!, course.endDate!)} sessions",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5B8DEF)),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AnnouncementsScreen(
                                        courseId: course.courseId,
                                        classId: c.classId ?? '',
                                        className: c.day,
                                        courseTitle: course.title,
                                        userId: widget.userId,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D9E75).withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.notifications_outlined, size: 15, color: Color(0xFF1D9E75)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (course.classes.isEmpty)
            Material(
              color: const Color(0xFFF1EFE8),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                onTap: () => _showAddClassSheet(course),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF1D9E75)),
                      SizedBox(width: 6),
                      Text("Add Class", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D9E75))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text("No courses yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
        const SizedBox(height: 6),
        Text('Tap "Add Course" to get started', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ],
    ),
  );
}

// ── AI Chat Screen with Gemini ────────────────────────────────────────────────

class _AIChatScreen extends StatefulWidget {
  final List<Course> courses;
  final String userId;
  const _AIChatScreen({required this.courses, required this.userId});

  @override
  State<_AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<_AIChatScreen> {
  final TextEditingController _inputCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();
  final ApiService             _apiService = ApiService();
  final List<ChatMessage>      _messages   = [];
  bool _isThinking = false;

  // ── Replace with your actual Gemini API key ──────────────────────────────
  static const String _geminiKey = 'your_gemini_api_key_here';

  static const List<Map<String, String>> _quickActions = [
    {"label": "Who didn't submit assignments?", "icon": "📋"},
    {"label": "Students with missing grades",   "icon": "📊"},
    {"label": "Students with 7+ absences",      "icon": "⚠️"},
    {"label": "Send announcement to a class",   "icon": "📢"},
    {"label": "Show course summary",            "icon": "📚"},
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "👋 Hello Doctor! I'm your AI assistant powered by Gemini.\n\n"
          "I can help you with:\n"
          "• Missing assignment submissions\n"
          "• Students without grades\n"
          "• Attendance warnings (7+ absences)\n"
          "• Sending announcements to classes\n\n"
          "Try one of the quick actions below!",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Fetch all real data from backend ─────────────────────────────────────
  Future<Map<String, dynamic>> _fetchAllData() async {
    final data = <String, dynamic>{};

    data['courses'] = widget.courses.map((c) => {
      'courseId': c.courseId,
      'title': c.title,
      'students': c.students,
      'attendance': c.attendance,
      'classes': c.classes.map((cl) => {
        'classId': cl.classId,
        'day': cl.day,
        'room': cl.room,
        'startTime': cl.startTime,
        'endTime': cl.endTime,
      }).toList(),
    }).toList();

    final missingSubmissions = <Map<String, dynamic>>[];
    final missingGrades      = <Map<String, dynamic>>[];
    final absenceWarnings    = <Map<String, dynamic>>[];

    for (final course in widget.courses) {
      try {
        final submissions = await _apiService.getMissingSubmissions(courseId: course.courseId);
        for (final s in submissions) {
          missingSubmissions.add({...s, 'courseName': course.title});
        }
      } catch (_) {}

      try {
        final grades = await _apiService.getMissingGrades(courseId: course.courseId);
        for (final g in grades) {
          missingGrades.add({...g, 'courseName': course.title});
        }
      } catch (_) {}

      try {
        final report = await _apiService.getCourseAttendanceReportData(course.courseId);
        final students = (report['students'] as List? ?? []);
        for (final s in students) {
          if ((s['absent'] as int? ?? 0) >= 7) {
            absenceWarnings.add({
              ...s,
              'courseName': course.title,
              'courseId': course.courseId,
            });
          }
        }
      } catch (_) {}
    }

    data['missingSubmissions'] = missingSubmissions;
    data['missingGrades']      = missingGrades;
    data['absenceWarnings']    = absenceWarnings;

    return data;
  }

  // ── Send message to Gemini with real data context ─────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _isThinking = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      final data = await _fetchAllData();

      final aiText = await _apiService.sendAiMessage(
        message: text,
        context: data,
      );

      if (aiText.contains('SEND_ANNOUNCEMENT|')) {
        await _handleAnnouncementCommand(aiText);
      } else {
        setState(() {
          _isThinking = false;
          _messages.add(ChatMessage(text: aiText, isUser: false));
        });
      }
    } catch (e) {
      setState(() {
        _isThinking = false;
        _messages.add(ChatMessage(text: "❌ Error: $e", isUser: false));
      });
    }

    _scrollToBottom();
  }

  // ── Handle announcement command from Gemini ───────────────────────────────
  Future<void> _handleAnnouncementCommand(String aiText) async {
    try {
      final lines = aiText.split('\n');
      final commands = <String>[];
      final displayLines = <String>[];

      for (final line in lines) {
        if (line.trim().startsWith('SEND_ANNOUNCEMENT|')) {
          commands.add(line.trim());
        } else {
          displayLines.add(line);
        }
      }

      if (commands.isEmpty) {
        setState(() {
          _isThinking = false;
          _messages.add(ChatMessage(
            text: displayLines.join('\n').trim(),
            isUser: false,
          ));
        });
        return;
      }

      int successCount = 0;
      final errors = <String>[];

      for (final command in commands) {
        final parts = command.split('|');
        if (parts.length >= 5) {
          final courseId = parts[1].trim();
          final classId  = parts[2].trim();
          final title    = parts[3].trim();
          final message  = parts[4].trim();

          try {
            await _apiService.createAnnouncement(
              userId:   widget.userId,
              courseId: courseId,
              classId:  classId,
              title:    title,
              message:  message,
            );
            successCount++;
          } catch (e) {
            errors.add('Failed for courseId=$courseId: $e');
          }
        }
      }

      final displayText = displayLines.join('\n').trim();
      final resultText = errors.isEmpty
          ? '✅ Announcement sent to $successCount course(s) successfully!'
          : '⚠️ Sent $successCount, failed ${errors.length}:\n${errors.join('\n')}';

      setState(() {
        _isThinking = false;
        _messages.add(ChatMessage(
          text: displayText.isNotEmpty
              ? '$displayText\n\n$resultText'
              : resultText,
          isUser: false,
        ));
      });
    } catch (e) {
      setState(() {
        _isThinking = false;
        _messages.add(ChatMessage(
          text: '⚠️ Failed to send announcements: $e',
          isUser: false,
        ));
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8)],
                        ),
                        child: const Center(child: Icon(Icons.smart_toy_rounded, color: Color(0xFF1D9E75), size: 22)),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("AI Assistant", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          Text("Powered by Gemini", style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            const Text("Online", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: [
                              ..._messages.map((m) => _buildMessage(m)),
                              if (_isThinking) _buildThinking(),
                              if (_messages.length == 1 && !_isThinking) _buildQuickActions(),
                            ],
                          ),
                        ),
                        _buildInputBar(),
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

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1D9E75) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Text(
                message.text,
                style: TextStyle(fontSize: 13.5, color: isUser ? Colors.white : const Color(0xFF2C2C2A), height: 1.5),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThinking() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: List.generate(3, (i) => _dot(i))),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + index * 200),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFD3D1C7), const Color(0xFF1D9E75), v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888780)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickActions.map((action) {
              return GestureDetector(
                onTap: () => _sendMessage(action["label"]!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1D9E75).withOpacity(0.30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    "${action["icon"]}  ${action["label"]}",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2C2C2A)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: "Ask me anything...",
                hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF1EFE8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF1D9E75).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Sheet Widget ───────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final IconData icon;
  final Widget  child;

  const _BottomSheet({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D9E75).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: const Color(0xFF1D9E75), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                        if (subtitle != null)
                          Text(subtitle!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}