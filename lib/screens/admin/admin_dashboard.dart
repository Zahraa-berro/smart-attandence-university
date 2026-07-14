import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'create_user_screen.dart';
import 'admin_course_detail_screen.dart';
import 'admin_courses_screen.dart';
import 'admin_sensor_overview_screen.dart';
import 'admin_users_screen.dart';
import '../login_screen.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  final ApiService _apiService = ApiService();
  bool _isLoadingStats = true;
  bool _isLoadingSensors = true;
  String? _statsError;
  int _doctors = 0;
  int _students = 0;
  int _admins = 0;
  int _coursesCount = 0;
  int _studentProfiles = 0;
  double _averageAttendance = 0.0;
  int _goodClassrooms = 0;
  int _moderateClassrooms = 0;
  int _criticalClassrooms = 0;
  double _averageTemperature = 0.0;
  double _averageHumidity = 0.0;
  double _averageAirQuality = 0.0;
  double _averageNoiseLevel = 0.0;
  String? _mostCriticalClassroom;
  bool _isRefreshing = false;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _brand = Color(0xFF1D9E75);
  static const Color _brandLight = Color(0xFF5DCAA5);
  static const Color _danger = Color(0xFFD85A30);
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      final stats = await _apiService.getAdminStats();
      if (!mounted) return;
      setState(() {
        _doctors = (stats['doctors'] as num?)?.toInt() ?? 0;
        _students = (stats['students'] as num?)?.toInt() ?? 0;
        _admins = (stats['admins'] as num?)?.toInt() ?? 0;
        _coursesCount = (stats['totalCourses'] as num?)?.toInt() ?? 0;
        _studentProfiles = (stats['totalStudentProfiles'] as num?)?.toInt() ?? 0;
        _averageAttendance = (stats['averageAttendance'] as num?)?.toDouble() ?? 0.0;
        _isLoadingStats = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingStats = false;
      });
    }

    await _loadSensorOverview();
  }

  Future<void> _loadSensorOverview() async {
    setState(() {
      _isLoadingSensors = true;
    });

    try {
      final overview = await _apiService.getAdminSensorOverview();
      if (!mounted) return;
      setState(() {
        _goodClassrooms = (overview['goodClassrooms'] as num?)?.toInt() ?? 0;
        _moderateClassrooms = (overview['moderateClassrooms'] as num?)?.toInt() ?? 0;
        _criticalClassrooms = (overview['criticalClassrooms'] as num?)?.toInt() ?? 0;
        _averageTemperature = (overview['averageTemperature'] as num?)?.toDouble() ?? 0.0;
        _averageHumidity = (overview['averageHumidity'] as num?)?.toDouble() ?? 0.0;
        _averageAirQuality = (overview['averageAirQuality'] as num?)?.toDouble() ?? 0.0;
        _averageNoiseLevel = (overview['averageNoiseLevel'] as num?)?.toDouble() ?? 0.0;
        _mostCriticalClassroom = overview['mostCriticalClassroom'] as String?;
        _isLoadingSensors = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSensors = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // ── Gradient header bg ───────────────────────────────────────────
          Container(
            height: 280,
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
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.09),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                FadeTransition(opacity: _fade, child: _buildTopBar()),

                const SizedBox(height: 22),

                // ── White sheet ────────────────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  40,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_statsError != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _statsError!,
                                        style: const TextStyle(
                                          color: _danger,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),

                                    _analyticsSection(context),
                                    const SizedBox(height: 20),
                                    _overviewCard(context),
                                    const SizedBox(height: 24),
                                    _sectionHeader(
                                      "Manage Users",
                                      "Create & configure accounts",
                                    ),
                                    const SizedBox(height: 16),
                                    _roleCard(
                                      context,
                                      title: "Add Staff",
                                      subtitle:
                                          "Create professor or assistant account",
                                      icon: Icons.school_rounded,
                                      accentColor: const Color(0xFF5B8DEF),
                                      role: "staff",
                                      count: _isLoadingStats
                                          ? "Loading..."
                                          : "$_doctors doctor accounts",
                                    ),
                                    const SizedBox(height: 14),
                                    _roleCard(
                                      context,
                                      title: "Add Student",
                                      subtitle: "Create a new student account",
                                      icon: Icons.person_rounded,
                                      accentColor: const Color(0xFFEF9F27),
                                      role: "student",
                                      count: _isLoadingStats
                                          ? "Loading..."
                                          : "$_students student accounts",
                                    ),
                                    const SizedBox(height: 14),
                                    _roleCard(
                                      context,
                                      title: "Add Admin",
                                      subtitle: "Create a new administrator account",
                                      icon: Icons.admin_panel_settings_rounded,
                                      accentColor: const Color(0xFF1D9E75),
                                      role: "add_admin",
                                      count: _isLoadingStats
                                          ? "Loading..."
                                          : "$_admins admin accounts",
                                    ),
                                    const SizedBox(height: 14),
                                    _roleCard(
                                      context,
                                      title: "Manage Users",
                                      subtitle:
                                          "View, edit, deactivate accounts",
                                      icon: Icons.people_alt_rounded,
                                      accentColor: _brand,
                                      role: "admin",
                                      count: _isLoadingStats
                                          ? "Loading..."
                                          : "",
                                    ),
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

  // ── Top bar ───────────────────────────────────────────────────────────────
  Future<void> _refreshStats() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    await _loadStats();
    setState(() {
      _isRefreshing = false;
    });
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          // Admin avatar
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
            child: const Center(
              child: Text(
                "AD",
                style: TextStyle(
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
              const Text(
                "Admin Panel",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "Smart University System",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Refresh button
          GestureDetector(
            onTap: _refreshStats,
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

          // Logout
          GestureDetector(
            onTap: () => _confirmLogout(),
            child: Container(
              width: 40,
              height: 40,
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

  // ── Role card ─────────────────────────────────────────────────────────────
  Widget _analyticsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Admin Overview', 'Campus analytics at a glance'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.book_rounded,
                value: _isLoadingStats ? '...' : '$_coursesCount',
                label: 'Courses',
                accentColor: const Color(0xFF5B8DEF),
                onTap: () async {
                  if (_isLoadingStats) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminCoursesScreen()),
                  );
                  _loadStats();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.groups_rounded,
                value: _isLoadingStats ? '...' : '$_studentProfiles',
                label: 'Students',
                accentColor: const Color(0xFF1D9E75),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.bar_chart_rounded,
                value: _isLoadingStats ? '...' : '${_averageAttendance.toStringAsFixed(1)}%',
                label: 'Avg Attend.',
                accentColor: const Color(0xFFEF9F27),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _inkMuted,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: accentColor,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }

  Widget _overviewCard(BuildContext context) {
    final badgeText = _isLoadingSensors
        ? 'Loading...'
        : _criticalClassrooms > 0
            ? '$_criticalClassrooms critical'
            : 'All good';
    final badgeColor = _criticalClassrooms > 0 ? const Color(0xFFD85A30) : const Color(0xFF1D9E75);

    return GestureDetector(
      onTap: _showSensorOverview,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F8F3), Color(0xFFF6F1FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.70)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF6D5BFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.sensor_door_rounded, color: Color(0xFF6D5BFF), size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IoT Sensor Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 6),
                  Text('View live campus classroom sensor summary', style: TextStyle(fontSize: 13, color: _inkMuted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(badgeText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor)),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF6D5BFF)),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String role,
    required String count,
  }) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (role == "admin") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
          );
          _loadStats();
          return;
        }
        if (role == "add_admin") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateUserScreen(role: 'admin')),
          );
          _loadStats();
          return;
        }
        if (role == "courses") {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCoursesScreen()),
          );
          _loadStats();
          return;
        }
        if (role == "sensors") {
          _showSensorOverview();
          return;
        }
        if (role == "attendance" || role == "active_users") {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateUserScreen(role: role)),
        );
        _loadStats();
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
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
              // Accent top bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.4)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Icon container
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _inkMuted,
                            ),
                          ),
                          if (count.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                count,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Arrow
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSensorOverview() {
    if (_isLoadingSensors) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminSensorOverviewScreen()),
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
        if (subtitle.isNotEmpty)
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
            // Drag pill
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFD3D1C7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
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

            // Buttons side by side
            Row(
              children: [
                // Cancel button
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

                // Confirm logout button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
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
}
