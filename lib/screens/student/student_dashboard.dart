import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../login_screen.dart';
import '../../services/api_service.dart';
import 'student_seat_map_screen.dart';
import 'dart:async';

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
class StudentDashboard extends StatefulWidget {
  final String userId;

  const StudentDashboard({super.key, required this.userId});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState(



  );
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _courses = [];

  // ── Notifications state ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _notificationsLoading = false;
  Timer? _notifTimer;
  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isRefreshing = false;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const Color _brand = Color(0xFF1D9E75);
  static const Color _brandLight = Color(0xFF5DCAA5);
  static const Color _danger = Color(0xFFD85A30);
  static const Color _warning = Color(0xFFEF9F27);
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);
  static const Color _cardBg = Colors.white;

  @override
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });

    _loadStudentData();

    // Poll for new notifications every 30 seconds
    _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications();
    });
  }
// ── View PDF ──────────────────────────────────────────────────────────────
  void _viewPdf(String base64Str, String title) async {
    try {
      final bytes = base64Decode(base64Str);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$title.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: PDFView(filePath: file.path),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    }
  }
// ── Submit assignment ──────────────────────────────────────────────────────
  void _submitAssignment(String assignmentId, String title) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // ← ensures bytes are always loaded on web
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read file. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final base64Str = base64Encode(bytes);
    final studentName = _dashboardData?['profile']?['name']?.toString() ?? '';

    try {
      await _apiService.submitAssignment(
        assignmentId: assignmentId,
        studentId: widget.userId,
        studentName: studentName,
        pdfBase64: base64Str,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment submitted successfully!'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _refreshStudentData() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    await _loadStudentData();
    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dashboard = await _apiService.getStudentDashboard(
        userId: widget.userId,
      );
      final courses = await _apiService.getStudentCourses(
        userId: widget.userId,
      );

      if (!mounted) return;

      setState(() {
        _dashboardData = dashboard;
        _courses = courses;
      });
      print('=== COURSES DEBUG ===');
      for (final c in courses) {
        print('Course: ${c['courseName']}');
        print('  performancePercentage: ${c['performancePercentage']}');
        print('  attendancePercentage: ${c['attendancePercentage']}');
        print('  ALL KEYS: ${c.keys.toList()}');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }

    // Load notifications separately so a failure doesn't block the dashboard
    await _loadNotifications();
  }

  // ── Notifications fetch ───────────────────────────────────────────────────
  Future<void> _loadNotifications() async {
    setState(() => _notificationsLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getStudentNotifications(userId: widget.userId),
        _apiService.getUnreadNotificationsCount(userId: widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = results[0] as List<Map<String, dynamic>>;
        _unreadCount   = results[1] as int;
      });
    } catch (_) {
      // silently fail — notifications are non-critical
    } finally {
      if (mounted) setState(() => _notificationsLoading = false);
    }
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // WITH THIS:
  double get _overallGrade {
    if (_courses.isEmpty) return 0.0;
    final values = _courses
        .map((c) => (c['performancePercentage'] ?? c['attendancePercentage'] ?? 0).toDouble())
        .where((v) => v > 0)
        .toList();
    if (values.isEmpty) return 0.0;
    return values.fold(0.0, (double s, v) => s + v) / values.length;
  }

  double get _overallGPA {
    final pct = _overallGrade;
    if (pct >= 90) return 4.0;
    if (pct >= 85) return 3.7;
    if (pct >= 80) return 3.3;
    if (pct >= 75) return 3.0;
    if (pct >= 70) return 2.7;
    if (pct >= 65) return 2.3;
    if (pct >= 60) return 2.0;
    if (pct >= 55) return 1.7;
    if (pct >= 50) return 1.0;
    return 0.0;
  }

  double get _overallAttendance {
    if (_courses.isEmpty) return 0.0;
    final values = _courses
        .map((c) => (c['attendancePercentage'] ?? 0).toDouble())
        .toList();
    return values.fold(0.0, (double s, v) => s + v) / values.length;
  }

  int get enrolledCoursesCount =>
      (_dashboardData?['enrolledCoursesCount'] as int?) ?? _courses.length;

  double get performancePercentage {
    final value = _dashboardData?['performancePercentage'];
    if (value is num) return value.toDouble();
    return 0.0;
  }

  int get absences => (_dashboardData?['absencesCount'] as int?) ?? 0;

  int get maxAllowedAbsences =>
      (_dashboardData?['maxAllowedAbsences'] as int?) ?? 10;

  bool get hasAttendanceWarning => absences > maxAllowedAbsences;

  // ── Grade breakdown bottom sheet ──────────────────────────────────────────
  void _openGradeSheet(Map<String, dynamic> c) {
    HapticFeedback.lightImpact();
    final String courseName = c["courseName"]?.toString() ?? 'Course';
    final String courseCode = c["courseCode"]?.toString() ?? '';
    final Color accent = _courseColor(
      courseCode.isNotEmpty ? courseCode : courseName,
      0,
    );
    final int overall =
    ((c["performancePercentage"] ?? c["attendancePercentage"] ?? 0) as num)
        .toInt();
    final bool hasDetails =
        c.containsKey("midterm") &&
            c.containsKey("project") &&
            c.containsKey("final");

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
        return SizedBox(
          height: maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag pill
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3D1C7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Course title row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _courseIcon(c["courseName"]?.toString() ?? ''),
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c["courseName"]?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c["courseCode"]?.toString() ?? '',
                              style: const TextStyle(fontSize: 12, color: _inkMuted),
                            ),
                          ],
                        ),
                      ),
                      // Overall badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _gradeColor(overall).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$overall%",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _gradeColor(overall),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (hasDetails) ...[
                    _gradeComponentCard(
                      icon: Icons.edit_note_rounded,
                      label: "Midterm Exam",
                      score: (c["midterm"] as num).toInt(),
                      total: 100,
                      color: const Color(0xFF5B8DEF),
                    ),
                    const SizedBox(height: 10),
                    _gradeComponentCard(
                      icon: Icons.folder_open_rounded,
                      label: "Project",
                      score: (c["project"] as num).toInt(),
                      total: 100,
                      color: const Color(0xFF9B59B6),
                    ),
                    const SizedBox(height: 10),
                    _gradeComponentCard(
                      icon: Icons.fact_check_rounded,
                      label: "Final Exam",
                      score: (c["final"] as num).toInt(),
                      total: 100,
                      color: accent,
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        "Detailed grade breakdown is not available for this course.",
                        style: TextStyle(fontSize: 13, color: _inkMuted),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Divider + overall
                  const Divider(color: Color(0xFFF1EFE8), height: 1),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Overall Grade",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      Text(
                        "$overall%",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _gradeColor(overall),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: overall / 100.0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1EFE8),
                      valueColor: AlwaysStoppedAnimation<Color>(_gradeColor(overall)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Assignments & Announcements
                  Builder(
                    builder: (ctx) {
                      final String courseId = c["courseId"]?.toString() ?? '';
                      return FutureBuilder<List<dynamic>>(
                        future: Future.wait([
                          _apiService.getStudentCourseAssignments(
                            userId: widget.userId,
                            courseId: courseId,
                          ),
                          _apiService.getStudentCourseAnnouncements(
                            userId: widget.userId,
                            courseId: courseId,
                          ),
                        ]),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Text(
                                'Failed to load updates',
                                style: TextStyle(color: _inkMuted),
                              ),
                            );
                          }

                          final assignments =
                          (snapshot.data != null && snapshot.data!.isNotEmpty)
                              ? (snapshot.data![0] as List<Map<String, dynamic>>)
                              : <Map<String, dynamic>>[];
                          final announcements =
                          (snapshot.data != null && snapshot.data!.length > 1)
                              ? (snapshot.data![1] as List<Map<String, dynamic>>)
                              : <Map<String, dynamic>>[];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text(
                                'Assignments',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (assignments.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'No assignments yet.',
                                    style: TextStyle(color: _inkMuted),
                                  ),
                                )
                              else
                                Column(
                                  children: assignments.map((a) {
                                    final String title = a['title']?.toString() ?? '';
                                    final String desc = a['description']?.toString() ?? '';
                                    final String due = a['dueDate']?.toString() ?? '';
                                    final String? pdfBase64 = a['pdfBase64']?.toString();
                                    final String assignmentId = a['assignmentId']?.toString() ?? '';

                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8, top: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(desc, style: const TextStyle(color: _inkMuted)),
                                          ],
                                          if (due.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text('Due: $due', style: const TextStyle(color: _inkMuted, fontSize: 12)),
                                          ],
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              // ── View PDF button ──────────────────────────────────────
                                              if (pdfBase64 != null && pdfBase64.isNotEmpty)
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () => _viewPdf(pdfBase64, title),
                                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                                                    label: const Text('View PDF', style: TextStyle(fontSize: 12)),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: const Color(0xFF9B59B6),
                                                      side: const BorderSide(color: Color(0xFF9B59B6)),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                    ),
                                                  ),
                                                ),
                                              if (pdfBase64 != null && pdfBase64.isNotEmpty) const SizedBox(width: 8),
                                              // ── Submit button ────────────────────────────────────────
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _submitAssignment(assignmentId, title),
                                                  icon: const Icon(Icons.upload_file_rounded, size: 14),
                                                  label: const Text('Submit', style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: _brand,
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),

                              const SizedBox(height: 14),
                              const Text(
                                'Announcements',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (announcements.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'No announcements yet.',
                                    style: TextStyle(color: _inkMuted),
                                  ),
                                )
                              else
                                Column(
                                  children: announcements.map((a) {
                                    final String title = a['title']?.toString() ?? '';
                                    final String msg = a['message']?.toString() ?? '';
                                    final String created =
                                        a['createdAt']?.toString() ??
                                            a['created_at']?.toString() ??
                                            '';
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8, top: 4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _cardBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          if (msg.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(msg, style: const TextStyle(color: _inkMuted)),
                                          ],
                                          if (created.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              created,
                                              style: const TextStyle(color: _inkMuted, fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _userInitials {
    final name = _dashboardData?['profile']?['name']?.toString() ?? '';
    if (name.isEmpty) return 'ST';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  String get _studentSubtitle {
    final studentId = _dashboardData?['profile']?['studentId']?.toString();
    final department = _dashboardData?['profile']?['department']?.toString();
    if (studentId == null || studentId.isEmpty) {
      return department ?? '';
    }
    if (department == null || department.isEmpty) {
      return 'ID: $studentId';
    }
    return 'ID: $studentId • $department';
  }

  Widget _gradeComponentCard({
    required IconData icon,
    required String label,
    required int score,
    required int total,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / total.toDouble(),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1EFE8),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "$score",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: "/$total",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool warning = hasAttendanceWarning;

    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // ── Gradient background ─────────────────────────────────────────
          Container(
            height: 300,
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

          // Decorative blobs
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────────
                FadeTransition(opacity: _fadeAnim, child: _buildHeader()),

                const SizedBox(height: 12),

                // ── Warning banner ─────────────────────────────────────────
                if (warning)
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildWarningBanner(),
                  ),

                if (warning) const SizedBox(height: 12),

                // ── Stats strip ─────────────────────────────────────────────
                FadeTransition(opacity: _fadeAnim, child: _buildStatsStrip()),

                const SizedBox(height: 20),

                // ── White sheet ─────────────────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Drag pill
                            Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(top: 12, bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3D1C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionHeader(
                                      "My Courses",
                                      "${_courses.length} enrolled",
                                    ),
                                    const SizedBox(height: 14),
                                    ..._courses.asMap().entries.map(
                                          (e) => _buildCourseCard(e.value, e.key),
                                    ),

                                    const SizedBox(height: 28),
                                    _sectionHeader(
                                      "Academic Performance",
                                      "This term",
                                    ),
                                    const SizedBox(height: 14),
                                    _buildGradeGrid(),

                                    const SizedBox(height: 28),
                                    _sectionHeader(
                                      "Attendance Summary",
                                      "Overall",
                                    ),
                                    const SizedBox(height: 14),
                                    _buildAttendanceSummary(),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userInitials,
                style: const TextStyle(
                  color: _brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dashboardData?['profile']?['name']?.toString() ?? 'Student',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _studentSubtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Notification bell with real unread count ────────────────────
          GestureDetector(
            onTap: _refreshStudentData,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          GestureDetector(
            onTap: _openNotifications,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: _danger,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 9 ? '9+' : '$_unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Warning banner ─────────────────────────────────────────────────────────
  Widget _buildWarningBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _danger.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.25),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attendance Warning",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "You have exceeded the maximum allowed absences",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats strip ────────────────────────────────────────────────────────────
  Widget _buildStatsStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _heroStat(
            icon: Icons.school_rounded,
            value: "$enrolledCoursesCount",
            label: "Courses",
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          _heroStat(
            icon: Icons.grade_rounded,
            value: "${_overallGrade.round()}%",
            label: "Avg Grade",
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          _heroStat(
            icon: Icons.event_available_rounded,
            value: "$absences",
            label: "Absences",
            color: absences > maxAllowedAbsences
                ? const Color(0xFFFFD0C4)
                : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Course card ────────────────────────────────────────────────────────────
  Widget _buildCourseCard(Map<String, dynamic> c, int index) {
    final String courseName = c["courseName"]?.toString() ?? 'Course';
    final String courseCode = c["courseCode"]?.toString() ?? '';
    final List<Map<String, dynamic>> schedule =
        (c["schedule"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final Map<String, dynamic> activeSchedule =
    schedule.isNotEmpty ? schedule.first : <String, dynamic>{};
    final String room = activeSchedule["room"]?.toString() ?? '';
    final String start = activeSchedule["startTime"]?.toString() ?? '';
    final String end = activeSchedule["endTime"]?.toString() ?? '';
    final int grade =
    ((c["performancePercentage"] ?? c["attendancePercentage"] ?? 0) as num)
        .toInt();
    final int att = ((c["attendancePercentage"] ?? 0) as num).toInt();
    final double attD = att.toDouble();
    final Color accent = _courseColor(courseCode, index);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.5)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _courseIcon(courseName),
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [courseCode, room]
                                  .where((s) => s.isNotEmpty)
                                  .join('  •  '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Grade icon button ──────────────────────────────
                      GestureDetector(
                        onTap: () => _openGradeSheet(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _gradeColor(grade).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$grade%",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _gradeColor(grade),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.bar_chart_rounded,
                                size: 14,
                                color: _gradeColor(grade),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _pill(
                        Icons.schedule_rounded,
                        [start, end].where((s) => s.isNotEmpty).join(' – '),
                        const Color(0xFF5B8DEF),
                      ),
                      const SizedBox(width: 8),
                      _pill(
                        Icons.location_on_outlined,
                        room.isNotEmpty ? room : courseCode,
                        _brand,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Attendance",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _inkMuted,
                        ),
                      ),
                      Text(
                        "$att%",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _attendanceColor(attD),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: attD / 100.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1EFE8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _attendanceColor(attD),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final courseIdValue = c["courseId"]?.toString() ?? '';
                        String realClassId = '';

                        if ((c["classId"] as String?)?.isNotEmpty == true) {
                          realClassId = c["classId"]!.toString();
                        } else if ((c["class_id"] as String?)?.isNotEmpty == true) {
                          realClassId = c["class_id"]!.toString();
                        }

                        if (realClassId.isEmpty) {
                          final sched =
                              (c["schedule"] as List<dynamic>?)
                                  ?.cast<Map<String, dynamic>>() ??
                                  [];
                          final Map<String, dynamic> act = sched.isNotEmpty
                              ? sched.first
                              : <String, dynamic>{};
                          if ((act["classId"] as String?)?.isNotEmpty == true) {
                            realClassId = act["classId"]!.toString();
                          } else if ((act["class_id"] as String?)?.isNotEmpty == true) {
                            realClassId = act["class_id"]!.toString();
                          } else if ((act["id"] as String?)?.isNotEmpty == true) {
                            realClassId = act["id"]!.toString();
                          }
                        }

                        if (realClassId.isEmpty &&
                            c["classes"] is List &&
                            (c["classes"] as List).isNotEmpty) {
                          final Map<String, dynamic> first =
                          (c["classes"] as List).first as Map<String, dynamic>;
                          if ((first["classId"] as String?)?.isNotEmpty == true) {
                            realClassId = first["classId"]!.toString();
                          } else if ((first["class_id"] as String?)?.isNotEmpty == true) {
                            realClassId = first["class_id"]!.toString();
                          } else if ((first["id"] as String?)?.isNotEmpty == true) {
                            realClassId = first["id"]!.toString();
                          }
                        }

                        debugPrint(
                          'NAV -> courseId: $courseIdValue, classId: $realClassId',
                        );

                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, animation, _) =>
                                StudentSeatMapScreen(
                                  userId: widget.userId,
                                  courseTitle: courseName,
                                  courseCode: courseCode,
                                  accentColor: accent,
                                  occupiedSeats: const {},
                                  courseId: courseIdValue,
                                  classId: realClassId,
                                ),
                            transitionsBuilder: (_, animation, _, child) =>
                                SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    ),
                                  ),
                                  child: child,
                                ),
                            transitionDuration:
                            const Duration(milliseconds: 380),
                          ),
                        );
                      },
                      icon: Icon(Icons.event_seat_rounded, size: 15, color: accent),
                      label: Text(
                        "View Seat Map",
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: accent.withOpacity(0.05),
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

  // ── Grade grid ─────────────────────────────────────────────────────────────
  Widget _buildGradeGrid() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5DCAA5), Color(0xFF1D9E75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _brand.withOpacity(0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(  // ADD THIS
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Overall GPA",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _overallGPA.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4, left: 4),
                            child: Text(
                              "/ 4.0",
                              style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_overallGrade.toStringAsFixed(1)}% average",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Spring Semester 2025",
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),  // END Expanded
              const SizedBox(width: 12),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        ..._courses.map((c) => _gradeRow(c)),
      ],
    );
  }

  Widget _gradeRow(Map<String, dynamic> c) {
    final String courseName = c["courseName"]?.toString() ?? '';
    final String courseCode = c["courseCode"]?.toString() ?? '';
    final int grade =
    ((c["performancePercentage"] ?? c["attendancePercentage"] ?? 0) as num)
        .toInt();
    final double gradeD = grade.toDouble();
    final Color accent = _courseColor(
      courseCode.isNotEmpty ? courseCode : courseName,
      0,
    );
    return GestureDetector(
      onTap: () => _openGradeSheet(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_courseIcon(courseName), color: accent, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: gradeD / 100.0,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF1EFE8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _gradeColor(grade),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Row(
              children: [
                Text(
                  "$grade%",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _gradeColor(grade),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18, color: _inkMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Attendance summary ─────────────────────────────────────────────────────
  Widget _buildAttendanceSummary() {
    final int maxAbsences = 10;
    final double absencesD = absences.toDouble();
    final double maxAbsencesD = maxAbsences.toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _attendanceStat(
                "Absences",
                "$absences",
                absences > 7 ? _danger : _brand,
                Icons.cancel_outlined,
              ),
              _vDivider(),
              _attendanceStat(
                "Present",
                "${_overallAttendance.round()}%",
                _attendanceColor(_overallAttendance),
                Icons.check_circle_outline,
              ),
              _vDivider(),
              _attendanceStat(
                "Max Allowed",
                "$maxAbsences",
                _warning,
                Icons.block_outlined,
              ),
            ],
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF1EFE8), height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Absence Usage",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _inkMuted,
                ),
              ),
              Text(
                "$absences / $maxAbsences used",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: absences > 7 ? _danger : _brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: absencesD / maxAbsencesD,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1EFE8),
              valueColor: AlwaysStoppedAnimation<Color>(
                absences > 7 ? _danger : _brand,
              ),
            ),
          ),

          if (absences > 7) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _danger.withOpacity(0.20)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: _danger, size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Contact your advisor — exceeding the limit may result in course withdrawal.",
                      style: TextStyle(
                        fontSize: 11,
                        color: _danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attendanceStat(
      String label,
      String value,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _inkMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: const Color(0xFFF1EFE8));

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
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
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: _inkMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _gradeColor(int g) {
    if (g >= 85) return _brand;
    if (g >= 70) return _warning;
    return _danger;
  }

  Color _attendanceColor(num a) {
    if (a >= 85) return _brand;
    if (a >= 70) return _warning;
    return _danger;
  }

  Color _courseColor(String key, int index) {
    final colors = [
      const Color(0xFF5DCAA5),
      const Color(0xFF9B59B6),
      const Color(0xFFF0997B),
      const Color(0xFF45A29E),
      const Color(0xFFF1C40F),
    ];
    final seed = key.codeUnits.fold(0, (sum, code) => sum + code) + index;
    return colors[seed % colors.length];
  }

  IconData _courseIcon(String courseName) {
    final name = courseName.toLowerCase();
    if (name.contains('data')) return Icons.storage_rounded;
    if (name.contains('computer') || name.contains('software'))
      return Icons.computer_rounded;
    if (name.contains('lab') || name.contains('science'))
      return Icons.science_rounded;
    if (name.contains('math') || name.contains('statistics'))
      return Icons.calculate_rounded;
    if (name.contains('design') || name.contains('art'))
      return Icons.brush_rounded;
    return Icons.school_rounded;
  }

  // ── Time ago helper ────────────────────────────────────────────────────────
  String _formatTimeAgo(DateTime dt) {
    // Make sure we compare in UTC
    final now = DateTime.now().toUtc();
    final utc = dt.toUtc();
    final diff = now.difference(utc);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
  // ── Logout ─────────────────────────────────────────────────────────────────
  void _confirmLogout() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFD3D1C7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: _danger, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              "Log Out",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Are you sure you want to log out\nof your student account?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _inkMuted, height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: Color(0xFFD3D1C7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _apiService.clearFcmToken(userId: widget.userId);
                        if (!mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Log Out",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  void _openNotifications() {
    HapticFeedback.lightImpact();

    // Mark all as read when the sheet opens
    if (_unreadCount > 0) {
      _apiService.markAllNotificationsRead(userId: widget.userId);
      setState(() => _unreadCount = 0);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag pill
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
              const Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),

              if (_notificationsLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_notifications.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: _inkMuted.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "No notifications yet",
                          style: TextStyle(color: _inkMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _notificationTile(_notifications[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification tile (real API data) ──────────────────────────────────────
  Widget _notificationTile(Map<String, dynamic> n) {
    final bool isRead = n['isRead'] as bool? ?? true;
    final String type = n['type']?.toString() ?? '';
    final String title = n['title']?.toString() ?? '';
    final String msg = n['message']?.toString() ?? '';
    final DateTime? createdAt = n['createdAt'] != null
        ? DateTime.tryParse(n['createdAt'].toString())
        : null;
    final String timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : '';

    final (IconData icon, Color color) = switch (type) {
      'grade'           => (Icons.grade_rounded,          const Color(0xFF1D9E75)),
      'announcement'    => (Icons.campaign_rounded,        const Color(0xFF5B8DEF)),
      'assignment'      => (Icons.assignment_rounded,      const Color(0xFF9B59B6)),
      'absence_warning' => (Icons.warning_amber_rounded,   const Color(0xFFD85A30)),
      _                 => (Icons.notifications_rounded,   const Color(0xFF888780)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? _cardBg : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: isRead ? null : Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  msg,
                  style: const TextStyle(fontSize: 11, color: _inkMuted),
                ),
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeAgo,
                    style: const TextStyle(fontSize: 10, color: _inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}