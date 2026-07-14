import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../models/course.dart';
import '../../services/api_service.dart';
import 'class_list_screen.dart';
import 'attendance_report_screen.dart';
import 'grades_screen.dart';
import 'notification_screen.dart';
import 'assignments_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  final ApiService _apiService = ApiService();
  late Course _course;
  bool _hasChanges = false;
  bool _loadingRecentSession = true;
  bool _hasRecentSession = false;
  int _recentSessionTotal = 0;
  int _recentSessionPresent = 0;
  int _recentSessionAbsent = 0;

  AttendanceReport? _attendanceReport;
  bool _loadingAttendanceReport = true;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _loadRecentSessionStats();
    _loadAttendanceReport();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _attendanceColor(int pct) {
    if (pct >= 85) return const Color(0xFF1D9E75);
    if (pct >= 70) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  void _openGradesForClass(CourseClass courseClass) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GradesScreen(
          courseTitle: _course.title,
          courseId: _course.courseId,
          section: courseClass.day,
        ),
      ),
    );
  }

  void _openAssignmentsForClass(CourseClass courseClass) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentsScreen(
          courseId: _course.courseId,
          classId: courseClass.classId ?? '',
          className: courseClass.day,
          courseTitle: _course.title,
        ),
      ),
    );
  }

  void _openAttendanceForClass(CourseClass courseClass) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassListScreen(
          courseId: _course.courseId,
          className: _course.title,
          day: courseClass.day,
          room: courseClass.room,
          time: courseClass.startTime,
          classId: courseClass.classId ?? '',
          semesterStart: _course.startDate ?? DateTime(2026, 1, 2),
          semesterEnd: _course.endDate ?? DateTime(2026, 5, 28),
        ),
      ),
    );
    // Reload when coming back from attendance
    if (!mounted) return;
    await _loadAttendanceReport();
    await _loadRecentSessionStats();
  }

  Future<void> _loadRecentSessionStats() async {
    setState(() {
      _loadingRecentSession = true;
      _hasRecentSession = false;
    });

    try {
      final sessions = await _apiService.getCourseSessions(_course.courseId);
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final recentSessions = sessions.where((session) {
        return !session.date.isAfter(now) &&
            session.date.isAfter(weekAgo) &&
            session.status == 'completed';
      }).toList();

      if (recentSessions.isEmpty) {
        setState(() {
          _loadingRecentSession = false;
          _hasRecentSession = false;
        });
        return;
      }

      recentSessions.sort((a, b) => b.date.compareTo(a.date));
      final latestSession = recentSessions.first;
      final detail = await _apiService.getAttendanceSession(latestSession.sessionId);
      final total = detail.records.length;
      final present = detail.records.where((record) => record.record?.present == true).length;
      final absent = total - present;

      setState(() {
        _loadingRecentSession = false;
        _hasRecentSession = true;
        _recentSessionTotal = total;
        _recentSessionPresent = present;
        _recentSessionAbsent = absent;
      });
    } catch (_) {
      setState(() {
        _loadingRecentSession = false;
        _hasRecentSession = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant CourseDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.course.courseId != oldWidget.course.courseId) {
      _course = widget.course;
      _loadRecentSessionStats();
      _loadAttendanceReport();
    }
  }

  Future<void> _loadAttendanceReport() async {
    setState(() {
      _loadingAttendanceReport = true;
    });

    try {
      final report = await _apiService.getCourseAttendanceReport(_course.courseId);
      if (!mounted) return;
      setState(() {
        _attendanceReport = report;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _attendanceReport = null;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingAttendanceReport = false;
      });
    }
  }

  int get _overallAttendancePercent =>
      _attendanceReport?.attendancePercentage ?? _course.attendance;

  int get _overallPresent =>
      _attendanceReport?.totalPresent ??
      ((_course.students * _course.attendance / 100).round());

  int get _overallAbsent =>
      _attendanceReport?.totalAbsent ??
      (_course.students - _overallPresent);

  int get _overallSessions => _attendanceReport?.conductedCount ?? 0;

  int get _overallStudents => _attendanceReport?.totalStudents ?? _course.students;

  void _showAddStudentsToClass(CourseClass courseClass) {
    final studentIdCtrl = TextEditingController();
    bool saving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3D1C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person_add_alt_1_rounded,
                          color: Color(0xFF1D9E75), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Add Students to ${courseClass.day} Class",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              _course.title,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF888780),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Enter a student ID.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: studentIdCtrl,
                    decoration: InputDecoration(
                      hintText: "Student ID",
                      filled: true,
                      fillColor: const Color(0xFFF1EFE8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.badge_outlined,
                          color: Color(0xFF888780)),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorText!,
                      style: const TextStyle(
                        color: Color(0xFFD85A30),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final studentId = studentIdCtrl.text.trim();
                              if (studentId.isEmpty) {
                                setLocal(() => errorText = "Student ID is required.");
                                return;
                              }
                              setLocal(() {
                                saving = true;
                                errorText = null;
                              });
                              try {
                                await _apiService.enrollStudentInCourseClass(
                                  courseId: _course.courseId,
                                  classId: courseClass.classId ?? '',
                                  studentId: studentId,
                                  email: null,
                                );
                                if (!mounted) return;
                                _hasChanges = true;
                                await _refreshCourse();
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Student enrolled successfully."),
                                    backgroundColor: Color(0xFF1D9E75),
                                  ),
                                );
                              } catch (e) {
                                setLocal(() {
                                  saving = false;
                                  errorText = e
                                      .toString()
                                      .replaceFirst("Exception: ", "");
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(
                        saving ? "Adding..." : "Add Student",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    final attColor = _attendanceColor(_overallAttendancePercent);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
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
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context, _hasChanges),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF1D9E75),
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Live Session",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF1D9E75),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Faculty of Engineering",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: CircularProgressIndicator(
                                      value: _overallAttendancePercent / 100,
                                      strokeWidth: 6,
                                      backgroundColor: Colors.white.withOpacity(0.25),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  Text(
                                    "${_overallAttendancePercent}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _heroStat(
                                    Icons.people_alt_outlined,
                                    "${course.students}",
                                    "Students",
                                  ),
                                  const SizedBox(height: 10),
                                  _heroStat(
                                    Icons.class_outlined,
                                    "${course.classes.length}",
                                    "Scheduled Classes",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: SlideTransition(
                      position: _slideUp,
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD3D1C7),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              _sectionTitle("Class Schedule"),
                              const SizedBox(height: 12),
                              course.classes.isEmpty
                                  ? _card(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            "No classes scheduled yet",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: course.classes
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => _classCard(e.key, e.value),
                                          )
                                          .toList(),
                                    ),
                              const SizedBox(height: 24),
                              _sectionTitle("Attendance Overview"),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _attendanceCard(
                                    label: "Total",
                                    value: _loadingAttendanceReport
                                        ? '...'
                                        : _attendanceReport != null
                                            ? '${_attendanceReport!.totalPresent + _attendanceReport!.totalAbsent}'
                                            : '—',
                                    icon: Icons.groups_rounded,
                                    iconColor: const Color(0xFF5B8DEF),
                                    bgColor: const Color(0xFF5B8DEF).withOpacity(0.08),
                                  ),
                                  const SizedBox(width: 10),
                                  _attendanceCard(
                                    label: "Present",
                                    value: _loadingAttendanceReport
                                        ? '...'
                                        : _attendanceReport != null
                                            ? '${_attendanceReport!.totalPresent}'
                                            : '—',
                                    icon: Icons.check_circle_rounded,
                                    iconColor: const Color(0xFF1D9E75),
                                    bgColor: const Color(0xFF1D9E75).withOpacity(0.08),
                                  ),
                                  const SizedBox(width: 10),
                                  _attendanceCard(
                                    label: "Absent",
                                    value: _loadingAttendanceReport
                                        ? '...'
                                        : _attendanceReport != null
                                            ? '${_attendanceReport!.totalAbsent}'
                                            : '—',
                                    icon: Icons.cancel_rounded,
                                    iconColor: const Color(0xFFD85A30),
                                    bgColor: const Color(0xFFD85A30).withOpacity(0.08),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_loadingAttendanceReport)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Loading aggregated attendance data...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              else if (_attendanceReport == null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Attendance data is not available yet.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Showing aggregated attendance across all completed sessions.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Overall Attendance Rate",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF444441),
                                          ),
                                        ),
                                        Text(
                                          "${_overallAttendancePercent}%",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _attendanceColor(_overallAttendancePercent),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _overallAttendancePercent / 100,
                                        minHeight: 8,
                                        backgroundColor: const Color(0xFFF1EFE8),
                                        valueColor: AlwaysStoppedAnimation<Color>(attColor),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _dot(const Color(0xFF1D9E75)),
                                        const SizedBox(width: 5),
                                        Text(
                                          "Present ($_overallPresent)",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF888780),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        _dot(const Color(0xFFD85A30)),
                                        const SizedBox(width: 5),
                                        Text(
                                          "Absent ($_overallAbsent)",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF888780),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1D9E75).withOpacity(0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AttendanceReportScreen(
                                            course: course,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.bar_chart_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "View Full Attendance Report",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _refreshCourse() async {
    try {
      final updated = await _apiService.getCourse(_course.courseId);
      if (!mounted) return;
      setState(() {
        _course = updated;
      });
      await _loadAttendanceReport();
    } catch (_) {
      // Keep the current view if refresh fails; the change flag still forces parent updates.
    }
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A1A2E),
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: child,
  );

  Widget _attendanceCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888780),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _classCard(int index, CourseClass c) {
    final colors = [
      const Color(0xFF5B8DEF),
      const Color(0xFF1D9E75),
      const Color(0xFFEF9F27),
      const Color(0xFF9B59B6),
      const Color(0xFFD85A30),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.class_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${c.day} Class",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Color(0xFF888780)),
                              const SizedBox(width: 4),
                              Text(
                                "${c.startTime} – ${c.endTime}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888780),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.meeting_room_outlined,
                                  size: 12, color: Color(0xFF888780)),
                              const SizedBox(width: 4),
                              Text(
                                c.room,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888780),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.people_alt_outlined,
                            label: "Attendance",
                            color: color,
                            onTap: () => _openAttendanceForClass(c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.grade_rounded,
                            label: "Grades",
                            color: color,
                            onTap: () => _openGradesForClass(c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.assignment_rounded,
                            label: "Assignments",
                            color: color,
                            onTap: () => _openAssignmentsForClass(c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.person_add_alt_1_rounded,
                            label: "Add Student",
                            color: color,
                            onTap: () => _showAddStudentsToClass(c),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}