// attendance_report_screen.dart
import 'package:flutter/material.dart';

import '../../models/attendance.dart';
import '../../models/course.dart';
import '../../services/api_service.dart';

class AttendanceReportScreen extends StatefulWidget {
  final Course course;

  const AttendanceReportScreen({super.key, required this.course});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Future<AttendanceReport> _reportFuture;

  static const int _absenceWarningThreshold = 7;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _reportFuture = _loadReport();
    _ctrl.forward();
  }

  Future<AttendanceReport> _loadReport() {
    return _apiService.getCourseAttendanceReport(widget.course.courseId);
  }

  Future<void> _refreshReport() async {
    setState(() {
      _reportFuture = _loadReport();
    });
    await _reportFuture;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _attendanceColor(double pct) {
    if (pct >= 0.85) return const Color(0xFF1D9E75);
    if (pct >= 0.70) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _pct(int part, int total) {
    if (total == 0) return "0%";
    return "${(part / total * 100).toStringAsFixed(1)}%";
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          Container(
            height: 260,
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
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<AttendanceReport>(
              future: _reportFuture,
              builder: (context, snapshot) {
                final report = snapshot.data;
                final warnStudents =
                    report?.students
                        .where((s) => s.absent >= _absenceWarningThreshold)
                        .toList() ??
                    [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              course.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _refreshReport,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          _summaryChip(
                            Icons.calendar_month_rounded,
                            "${report?.conductedCount ?? 0}/${report?.totalSessions ?? 0}",
                            "Sessions",
                          ),
                          const SizedBox(width: 10),
                          _summaryChip(
                            Icons.people_alt_outlined,
                            "${report?.totalStudents ?? 0}",
                            "Students",
                          ),
                          const SizedBox(width: 10),
                          _summaryChip(
                            Icons.warning_amber_rounded,
                            "${warnStudents.length}",
                            "At Risk",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
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
                            child: _bodyForSnapshot(snapshot, warnStudents),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyForSnapshot(
    AsyncSnapshot<AttendanceReport> snapshot,
    List<AttendanceStudentStat> warnStudents,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        snapshot.data == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
      );
    }

    if (snapshot.hasError && snapshot.data == null) {
      return _messageState(
        Icons.error_outline,
        "Could not load report",
        snapshot.error.toString(),
      );
    }

    final report = snapshot.data;
    if (report == null) {
      return _messageState(
        Icons.bar_chart_outlined,
        "No report found",
        "Seed attendance sample data first.",
      );
    }

    final overallPct = report.conductedCount == 0 || report.students.isEmpty
        ? 0.0
        : report.totalPresent /
              (report.conductedCount * report.students.length);

    return RefreshIndicator(
      onRefresh: _refreshReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD3D1C7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _sectionTitle("Overall Attendance"),
            const SizedBox(height: 12),
            Row(
              children: [
                _bigStatCard(
                  label: "Present",
                  value: report.totalPresent.toString(),
                  sub: _pct(
                    report.totalPresent,
                    report.totalPresent + report.totalAbsent,
                  ),
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF1D9E75),
                ),
                const SizedBox(width: 10),
                _bigStatCard(
                  label: "Absent",
                  value: report.totalAbsent.toString(),
                  sub: _pct(
                    report.totalAbsent,
                    report.totalPresent + report.totalAbsent,
                  ),
                  icon: Icons.cancel_rounded,
                  color: const Color(0xFFD85A30),
                ),
                const SizedBox(width: 10),
                _bigStatCard(
                  label: "Rate",
                  value: "${(overallPct * 100).toStringAsFixed(0)}%",
                  sub: "Overall",
                  icon: Icons.insights_rounded,
                  color: _attendanceColor(overallPct),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Class Attendance Rate",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444441),
                        ),
                      ),
                      Text(
                        "${(overallPct * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _attendanceColor(overallPct),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overallPct,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFF1EFE8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _attendanceColor(overallPct),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle("Student Breakdown"),
            const SizedBox(height: 12),
            _card(
              child: Column(
                children: [
                  _tableHeader(),
                  ...report.students.asMap().entries.map(
                    (entry) => _studentRow(entry.key, entry.value),
                  ),
                ],
              ),
            ),
            if (warnStudents.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle("At Risk Students"),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  children: warnStudents
                      .asMap()
                      .entries
                      .map((entry) => _warnRow(entry.key, entry.value))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageState(IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xFF888780)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888780)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text("Student", style: _headerStyle())),
          Expanded(
            child: Text(
              "Present",
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
          Expanded(
            child: Text(
              "Absent",
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
          Expanded(
            child: Text(
              "Rate",
              textAlign: TextAlign.center,
              style: _headerStyle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(int index, AttendanceStudentStat student) {
    final total = student.present + student.absent;
    final pct = total == 0 ? 0.0 : student.present / total;
    final color = _attendanceColor(pct);
    final isWarn = student.absent >= _absenceWarningThreshold;

    return Column(
      children: [
        if (index > 0) const Divider(height: 1, color: Color(0xFFF1EFE8)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isWarn
                          ? const Color(0xFFD85A30).withOpacity(0.15)
                          : const Color(0xFF1D9E75).withOpacity(0.15),
                      child: Text(
                        student.name.isNotEmpty ? student.name[0] : "?",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWarn
                              ? const Color(0xFFD85A30)
                              : const Color(0xFF1D9E75),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "ID: ${student.studentId}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF888780),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWarn)
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFD85A30),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  "${student.present}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D9E75),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  "${student.absent}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isWarn
                        ? const Color(0xFFD85A30)
                        : const Color(0xFF888780),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${(pct * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _warnRow(int index, AttendanceStudentStat student) {
    return Column(
      children: [
        if (index > 0) const Divider(height: 1, color: Color(0xFFF1EFE8)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFD85A30).withOpacity(0.15),
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : "?",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD85A30),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      "${student.absent} absences",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD85A30),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bigStatCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
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
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
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
            sub,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF888780),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

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

  TextStyle _headerStyle() => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF888780),
    letterSpacing: 0.3,
  );
}
