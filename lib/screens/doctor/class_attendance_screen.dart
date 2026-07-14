// class_attendance_screen.dart
import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../services/api_service.dart';
import 'air_quality_screen.dart';
import 'noise_screen.dart';
import 'seat_led_screen.dart';

class ClassAttendanceScreen extends StatefulWidget {
  final String className;
  final AttendanceSession session;

  const ClassAttendanceScreen({
    super.key,
    required this.className,
    required this.session,
  });

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final Map<String, AnimationController> _pulseControllers = {};

  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Future<AttendanceSessionDetail> _detailFuture;
  List<AttendanceStudentRecord> _records = [];
  final Set<String> _updatingStudents = {};

  final double _noiseLevel = 32.0;
  final int _airQuality = 42;
  final bool _cardSensorOnline = true;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    _detailFuture = _loadAttendance();
  }

  Future<AttendanceSessionDetail> _loadAttendance() async {
    final detail = await _apiService.getAttendanceSession(
      widget.session.sessionId,
    );
    if (!mounted) return detail;
    setState(() {
      _records = detail.records;
      for (final item in _records) {
        _initPulse(item.student.studentId, item.record?.present == true);
      }
    });
    return detail;
  }

  Future<void> _refreshAttendance() async {
    // Don't clear _records here — keep showing old data while reloading
    setState(() {
      _detailFuture = _loadAttendance();
    });
    await _detailFuture;
  }
  void _initPulse(String id, bool present) {
    if (_pulseControllers.containsKey(id)) return;
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseControllers[id] = ctrl;
    if (present) ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    for (final c in _pulseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleManual(int index, bool val) async {
    final studentId = _records[index].student.studentId;
    final oldRecord = _records[index].record;
    final oldPresent = oldRecord?.present == true;

    setState(() {
      _updatingStudents.add(studentId);
      _records[index] = AttendanceStudentRecord(
        student: _records[index].student,
        record: AttendanceRecord(
          id: oldRecord?.id ?? '',
          recordId: oldRecord?.recordId ?? '',
          sessionId: widget.session.sessionId,
          courseId: widget.session.courseId,
          studentId: studentId,
          present: val,
          detectedBy: val ? 'Manual' : null,
        ),
      );
      _setPulse(studentId, val);
    });

    try {
      final saved = await _apiService.updateAttendanceRecord(
        widget.session.sessionId,
        studentId,
        val,
      );
      if (!mounted) return;
      setState(() {
        _records[index] = AttendanceStudentRecord(
          student: _records[index].student,
          record: saved,
        );
        _updatingStudents.remove(studentId);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _records[index] = AttendanceStudentRecord(
          student: _records[index].student,
          record: oldRecord,
        );
        _setPulse(studentId, oldPresent);
        _updatingStudents.remove(studentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFD85A30),
        ),
      );
    }
  }

  void _setPulse(String studentId, bool present) {
    if (present) {
      _pulseControllers[studentId]?.repeat(reverse: true);
    } else {
      _pulseControllers[studentId]?.stop();
      _pulseControllers[studentId]?.reset();
    }
  }

  int get _presentCount =>
      _records.where((item) => item.record?.present == true).length;

  Color _attendanceColor(double pct) {
    if (pct >= 0.85) return const Color(0xFF1D9E75);
    if (pct >= 0.70) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _formatDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${d.day} ${months[d.month]} ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final total = _records.length;
    final pct = total == 0 ? 0.0 : _presentCount / total;
    final attColor = _attendanceColor(pct);

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
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
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
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.className,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatDate(widget.session.date),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _refreshAttendance,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: pct,
                                strokeWidth: 6,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                              Text(
                                "${(pct * 100).round()}%",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        _headerStat(
                          Icons.people_alt_outlined,
                          "$total",
                          "Total",
                        ),
                        const SizedBox(width: 20),
                        _headerStat(
                          Icons.check_circle_outline,
                          "$_presentCount",
                          "Present",
                        ),
                        const SizedBox(width: 20),
                        _headerStat(
                          Icons.cancel_outlined,
                          "${total - _presentCount}",
                          "Absent",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(
                              top: 12,
                              bottom: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<AttendanceSessionDetail>(
                            future: _detailFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting &&
                                  _records.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1D9E75),
                                  ),
                                );
                              }

                              if (snapshot.hasError && _records.isEmpty) {
                                return _messageState(
                                  Icons.error_outline,
                                  "Could not load attendance",
                                  snapshot.error.toString(),
                                );
                              }

                              return RefreshIndicator(
                                onRefresh: _refreshAttendance,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    100,
                                  ),
                                  children: [
                                    _iotStrip(),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Students",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A2E),
                                          ),
                                        ),
                                        Text(
                                          "$_presentCount / $total present",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: attColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (_records.isEmpty)
                                      _messageState(
                                        Icons.people_outline,
                                        "No students found",
                                        "Seed attendance sample data first.",
                                      )
                                    else
                                      ..._records.asMap().entries.map(
                                            (e) =>
                                            _studentCard(e.key, e.value),
                                      ),
                                  ],
                                ),
                              );
                            },
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

  Widget _iotStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Smart Classroom - IoT Status",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NoiseScreen()),
                  ),
                  child: _iotChip(
                    icon: Icons.volume_up_rounded,
                    label: "Noise",
                    value: "${_noiseLevel.round()} dB",
                    color: const Color(0xFFEF9F27),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AirQualityScreen()),
                  ),
                  child: _iotChip(
                    icon: Icons.air_rounded,
                    label: "AQI",
                    value: "$_airQuality",
                    color: const Color(0xFF1D9E75),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SeatLedScreen(
                      classId: widget.session.classId ?? '',
                    )),
                  ),
                  child: _iotChip(
                    icon: Icons.event_seat,
                    label: "Seat",
                    value: _cardSensorOnline ? "On" : "Off",
                    color: const Color(0xFF5B8DEF),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iotChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888780)),
          ),
        ],
      ),
    );
  }

  Widget _studentCard(int index, AttendanceStudentRecord item) {
    final present = item.record?.present == true;
    final detectedBy = item.record?.detectedBy;
    final id = item.student.studentId;
    final name = item.student.name;
    final image = item.student.imageUrl;
    final pulseCtrl = _pulseControllers[id]!;
    final updating = _updatingStudents.contains(id);

    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        final glow = present
            ? BoxShadow(
          color: const Color(0xFF1D9E75)
              .withOpacity(0.08 + 0.08 * pulseCtrl.value),
          blurRadius: 14 + 6 * pulseCtrl.value,
          offset: const Offset(0, 4),
        )
            : BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: present
                  ? const Color(0xFF1D9E75).withOpacity(0.25)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [glow],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF5DCAA5).withOpacity(0.15),
                        border: Border.all(
                          color: present
                              ? const Color(0xFF1D9E75).withOpacity(0.4)
                              : const Color(0xFFD3D1C7),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              name.isNotEmpty ? name[0] : "?",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: present
                                    ? const Color(0xFF1D9E75)
                                    : const Color(0xFF888780),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (present)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D9E75),
                            shape: BoxShape.circle,
                            border:
                            Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 11,
                            color: Color(0xFF888780),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "ID: $id",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888780),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (detectedBy != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF1D9E75).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            detectedBy,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D9E75),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: present
                            ? const Color(0xFF1D9E75).withOpacity(0.10)
                            : const Color(0xFFD85A30).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        present ? "Present" : "Absent",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: present
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFFD85A30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    updating
                        ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1D9E75),
                      ),
                    )
                        : Transform.scale(
                      scale: 0.80,
                      child: Switch(
                        value: present,
                        onChanged: (val) => _toggleManual(index, val),
                        activeColor: const Color(0xFF1D9E75),
                        activeTrackColor: const Color(
                          0xFF1D9E75,
                        ).withOpacity(0.30),
                        inactiveThumbColor: const Color(0xFFD85A30),
                        inactiveTrackColor: const Color(
                          0xFFD85A30,
                        ).withOpacity(0.20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
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
    );
  }
}