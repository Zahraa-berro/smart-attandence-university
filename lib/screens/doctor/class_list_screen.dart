import 'package:flutter/material.dart';
import 'session_list_screen.dart';

class ClassListScreen extends StatelessWidget {
  final String courseId;
  final String className;
  final String day;
  final String room;
  final String time;
  final String classId;
  final DateTime semesterStart;
  final DateTime semesterEnd;
  
  const ClassListScreen({
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
  Widget build(BuildContext context) {
    final List<Map<String, String>> classes = [
      {"title": className, "day": day, "room": room, "time": time, "classId": classId},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          Container(
            height: 240,
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
            right: -20,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: 500,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
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
                      const Expanded(
                        child: Text(
                          "Class Sessions",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                              Icons.school_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Smart",
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
                const SizedBox(height: 28),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(top: 12, bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Course Classes",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                "${classes.length} Class",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888780),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: classes.length,
                            itemBuilder: (context, index) {
                              final c = classes[index];
                              final colors = [
                                const Color(0xFF1D9E75),
                                const Color(0xFF5B8DEF),
                                const Color(0xFFEF9F27),
                              ];
                              final cardColor = colors[index % colors.length];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionListScreen(
                                        courseId: courseId,
                                        className: c["title"]!,
                                        day: c["day"]!,
                                        room: c["room"]!,
                                        time: c["time"]!,
                                        classId: c["classId"]!,
                                        semesterStart: semesterStart,
                                        semesterEnd: semesterEnd,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: const BorderRadius.horizontal(
                                            left: Radius.circular(18),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 46,
                                                    height: 46,
                                                    decoration: BoxDecoration(
                                                      color: cardColor.withOpacity(0.10),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    child: Icon(
                                                      Icons.menu_book_rounded,
                                                      color: cardColor,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          c["title"]!,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w700,
                                                            color: Color(0xFF1A1A2E),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          "${c["day"]} · ${c["room"]}",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 18),
                                              Row(
                                                children: [
                                                  _infoChip(
                                                    Icons.calendar_today_rounded,
                                                    c["day"]!,
                                                    const Color(0xFF1D9E75),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  _infoChip(
                                                    Icons.meeting_room_rounded,
                                                    c["room"]!,
                                                    const Color(0xFF5B8DEF),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 15,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    c["time"]!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: cardColor.withOpacity(0.10),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      "View Sessions",
                                                      style: TextStyle(
                                                        color: cardColor,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 16),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 18,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}