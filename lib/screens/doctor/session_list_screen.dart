import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../services/api_service.dart';
import 'class_attendance_screen.dart';

class SessionListScreen extends StatefulWidget {
  final String courseId;
  final String className;
  final String day;
  final String room;
  final String time;
  final String classId;
  final DateTime semesterStart;
  final DateTime semesterEnd;

  const SessionListScreen({
    super.key,
    required this.courseId,
    required this.className,
    required this.day,
    required this.room,
    required this.time,
    required this.classId,
    required this.semesterStart,
    required this.semesterEnd,
  });

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<AttendanceSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<List<AttendanceSession>> _loadSessions() {
    return _apiService.getCourseSessionsByClass(widget.courseId, widget.classId);
  }

  Future<void> _refreshSessions() async {
    setState(() {
      _sessionsFuture = _loadSessions();
    });
    await _sessionsFuture;
  }

  bool _isPast(DateTime d) {
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _isToday(DateTime d) {
    final today = DateTime.now();
    return d.year == today.year && d.month == today.month && d.day == today.day;
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

  String _weekLabel(int index) => "Week ${index + 1}";

  @override
  Widget build(BuildContext context) {
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
            child: FutureBuilder<List<AttendanceSession>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                final pastCount = sessions.where((s) => _isPast(s.date)).length;
                final totalCount = sessions.length;

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
                              widget.className,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _refreshSessions,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _summaryChip(
                                Icons.calendar_month_rounded,
                                "$totalCount Sessions",
                                "Total",
                              ),
                              const SizedBox(width: 12),
                              _summaryChip(
                                Icons.history_rounded,
                                "$pastCount Done",
                                "Past",
                              ),
                              const SizedBox(width: 12),
                              _summaryChip(
                                Icons.upcoming_rounded,
                                "${totalCount - pastCount} Left",
                                "Upcoming",
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: totalCount == 0 ? 0 : pastCount / totalCount,
                              minHeight: 6,
                              backgroundColor: Colors.white.withOpacity(0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_formatDate(widget.semesterStart)}  ->  ${_formatDate(widget.semesterEnd)}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Room: ${widget.room}  ·  Time: ${widget.time}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                                margin: const EdgeInsets.only(top: 12, bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD3D1C7),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${widget.day} Sessions",
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.meeting_room_outlined,
                                        size: 13,
                                        color: Color(0xFF888780),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.room,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888780),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _bodyForSnapshot(snapshot, sessions),
                            ),
                          ],
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
    AsyncSnapshot<List<AttendanceSession>> snapshot,
    List<AttendanceSession> sessions,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
      );
    }

    if (snapshot.hasError) {
      return _messageState(
        Icons.error_outline,
        "Could not load sessions",
        snapshot.error.toString(),
      );
    }

    if (sessions.isEmpty) {
      return _messageState(
        Icons.event_busy_outlined,
        "No sessions found",
        "Sessions will be generated based on course schedule.",
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshSessions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _sessionCard(index, sessions[index]),
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

  Widget _sessionCard(int index, AttendanceSession session) {
    final past = _isPast(session.date);
    final today = _isToday(session.date);

    Color accentColor;
    if (today) {
      accentColor = const Color(0xFF5B8DEF);
    } else if (past) {
      accentColor = const Color(0xFF1D9E75);
    } else {
      accentColor = const Color(0xFFD3D1C7);
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassAttendanceScreen(
              className: widget.className,
              session: session,
            ),
          ),
        );
        _refreshSessions();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: today
              ? Border.all(
                  color: const Color(0xFF5B8DEF).withOpacity(0.40),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(session.date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _weekLabel(index),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888780),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (today)
              _badge("Today", const Color(0xFF5B8DEF))
            else if (past)
              _badge("Completed", const Color(0xFF1D9E75))
            else
              _badge("Upcoming", const Color(0xFFD3D1C7)),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF888780),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

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
}