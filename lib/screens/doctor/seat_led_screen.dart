import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'seat_manager.dart';

class SeatLedScreen extends StatefulWidget {
  final String classId;
  const SeatLedScreen({super.key,required this.classId});

  @override
  State<SeatLedScreen> createState() => _SeatLedScreenState();
}

class _SeatLedScreenState extends State<SeatLedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<String> seats = [
    "A1",
    "A2",
    "A3",
    "A4",
    "A5",

    "B1",
    "B2",
    "B3",
    "B4",
    "B5",

    "C1",
    "C2",
    "C3",
    "C4",
    "C5",

    "D1",
    "D2",
    "D3",
    "D4",
    "D5",

    "E1",
    "E2",
    "E3",
    "E4",
    "E5",

    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
  ];
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadReservedSeats();

  }
  Future<void> _loadReservedSeats() async {
    try {
      final ApiService apiService = ApiService();
      final response = await apiService.getClassSeats(classId: widget.classId);
      final reserved = response
          .map((r) => r['seatNumber']?.toString())
          .whereType<String>()
          .toList();
      setState(() {
        for (final seat in reserved) {
          SeatManager.instance.markStudentDetected(seat);
        }
      });
    } catch (_) {}
  }
  @override
  void dispose() {
    _controller.dispose();
    SeatManager.instance.activeSeats.clear();
    super.dispose();
  }

  int get activeCount => SeatManager.instance.activeSeats.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          // ───────── Gradient Header ─────────
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

          // Decorative circles
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ───────── Top Bar ─────────
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
                          "Smart Seat System",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF1D9E75),
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Live",
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

                // ───────── Stats ─────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      _statCard(
                        title: "Active",
                        value: "$activeCount",
                        icon: Icons.event_seat_rounded,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        title: "Empty",
                        value: "${seats.length - activeCount}",
                        icon: Icons.weekend_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ───────── White Sheet ─────────
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
                              bottom: 20,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const Text(
                          "Classroom Layout",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            itemCount: seats.length,
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.78,
                            ),
                            itemBuilder: (context, index) {
                              final seatId = seats[index];
                              final active = SeatManager.instance
                                  .isSeatActive(seatId);

                              return AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return _seatWidget(
                                    seatId,
                                    active,
                                    _controller.value,
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // ───────── Legend ─────────
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _legend(
                                const Color(0xFF1D9E75),
                                "Student Detected",
                              ),
                              _legend(
                                const Color(0xFFE7E5DF),
                                "Empty Seat",
                              ),
                            ],
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

  // ───────── Seat Widget ─────────
  Widget _seatWidget(String seatId, bool active, double pulse) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: active
            ? const LinearGradient(
          colors: [
            Color(0xFF5DCAA5),
            Color(0xFF1D9E75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: active ? null : const Color(0xFFE7E5DF),
        boxShadow: active
            ? [
          BoxShadow(
            color: const Color(0xFF1D9E75)
                .withOpacity(0.25 + (pulse * 0.2)),
            blurRadius: 16 + (pulse * 6),
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_seat_rounded,
            size: 24,
            color: active
                ? Colors.white
                : const Color(0xFF888780),
          ),
          const SizedBox(height: 5),
          Text(
            seatId,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active
                  ? Colors.white
                  : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            active ? "ON" : "EMPTY",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.white.withOpacity(0.9)
                  : const Color(0xFF888780),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── Legend ─────────
  Widget _legend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444441),
          ),
        ),
      ],
    );
  }

  // ───────── Stat Card ─────────
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
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