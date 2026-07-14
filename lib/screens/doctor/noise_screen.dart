import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class NoiseScreen extends StatefulWidget {
  const NoiseScreen({super.key});

  @override
  State<NoiseScreen> createState() => _NoiseScreenState();
}

class _NoiseScreenState extends State<NoiseScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Timer _sensorTimer;
  final Random _rnd = Random();

  List<double> zoneDb = [28.0, 41.0, 35.0, 22.0];
  final List<String> zoneNames = ["Front", "Back", "Left", "Right"];
  final List<IconData> zoneIcons = [
    Icons.videocam_outlined,
    Icons.people_alt_outlined,
    Icons.window_outlined,
    Icons.door_front_door_outlined,
  ];

  // 📊 Noise history for chart
  List<double> history = [28, 30, 35, 33, 40, 38, 42];

  double get overallDb =>
      zoneDb.reduce((a, b) => a + b) / zoneDb.length;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _sensorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        for (int i = 0; i < zoneDb.length; i++) {
          zoneDb[i] =
              (zoneDb[i] + (_rnd.nextDouble() * 6 - 3)).clamp(15.0, 75.0);
        }

        // update graph
        history.add(overallDb);
        if (history.length > 20) {
          history.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _sensorTimer.cancel();
    super.dispose();
  }

  Color _noiseColor(double db) {
    if (db < 35) return const Color(0xFF1D9E75);
    if (db < 55) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _noiseLabel(double db) {
    if (db < 35) return "Quiet";
    if (db < 55) return "Moderate";
    return "Loud";
  }

  @override
  Widget build(BuildContext context) {
    final overall = overallDb;
    final overallColor = _noiseColor(overall);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3A3A8C),
                  Color(0xFF5B5FC7),
                  Color(0xFF8B7FD4)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const Text(
                        "Noise Level",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      _liveBadge(),
                    ],
                  ),
                ),

                // HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(
                                0.15 + 0.10 * _pulseCtrl.value),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.graphic_eq,
                                  color: Colors.white, size: 22),
                              Text(
                                "${overall.round()} dB",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _noiseLabel(overall),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          Text(
                            "Classroom average",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding:
                      const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle("Noise Trend"),
                          const SizedBox(height: 12),

                          // 📊 GRAPH ADDED HERE
                          _noiseChart(),

                          const SizedBox(height: 24),

                          _sectionTitle("Classroom Map — Noise Zones"),
                          const SizedBox(height: 16),

                          _roomMap(),

                          const SizedBox(height: 24),

                          _sectionTitle("Zone Breakdown"),
                          const SizedBox(height: 12),

                          ...List.generate(zoneDb.length, (i) => _zoneCard(i)),
                        ],
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

  // 📊 NOISE CHART
  Widget _noiseChart() {
    return _card(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minY: 10,
            maxY: 80,
            lineBarsData: [
              LineChartBarData(
                spots: history
                    .asMap()
                    .entries
                    .map((e) => FlSpot(
                  e.key.toDouble(),
                  e.value,
                ))
                    .toList(),
                isCurved: true,
                color: const Color(0xFF5B5FC7),
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF5B5FC7).withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SAME UI PARTS (UNCHANGED)
  Widget _roomMap() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live sensor map",
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888780),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1.6,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    // Room border
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFD3D1C7), width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF1EFE8),
                      ),
                    ),

                    // Front zone (top)
                    _zoneRegion(
                        left: 0,
                        top: 0,
                        width: w,
                        height: h * 0.28,
                        db: zoneDb[0],
                        label: "Front",
                        icon: Icons.videocam_outlined,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        )),

                    // Back zone (bottom)
                    _zoneRegion(
                        left: 0,
                        top: h * 0.72,
                        width: w,
                        height: h * 0.28,
                        db: zoneDb[1],
                        label: "Back",
                        icon: Icons.people_alt_outlined,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        )),

                    // Left zone
                    _zoneRegion(
                        left: 0,
                        top: h * 0.28,
                        width: w * 0.25,
                        height: h * 0.44,
                        db: zoneDb[2],
                        label: "Left",
                        icon: Icons.window_outlined,
                        borderRadius: BorderRadius.zero),

                    // Right zone
                    _zoneRegion(
                        left: w * 0.75,
                        top: h * 0.28,
                        width: w * 0.25,
                        height: h * 0.44,
                        db: zoneDb[3],
                        label: "Right",
                        icon: Icons.door_front_door_outlined,
                        borderRadius: BorderRadius.zero),

                    // Center — teacher / board area
                    Positioned(
                      left: w * 0.25,
                      top: h * 0.28,
                      width: w * 0.50,
                      height: h * 0.44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          border: Border.all(
                              color: const Color(0xFFD3D1C7)
                                  .withOpacity(0.5)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school_outlined,
                                color: Color(0xFF888780), size: 20),
                            SizedBox(height: 4),
                            Text(
                              "Classroom",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888780),
                                  fontWeight: FontWeight.w600),
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

  Widget _zoneRegion({
    required double left,
    required double top,
    required double width,
    required double height,
    required double db,
    required String label,
    required IconData icon,
    required BorderRadius borderRadius,
  }) {
    final color = _noiseColor(db);
    return Positioned(
      left: left,
      top: top,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: borderRadius,
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            Text(
              "${db.round()}dB",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoneCard(int i) {
    final db = zoneDb[i];
    final color = _noiseColor(db);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(zoneIcons[i], color: color),
          const SizedBox(width: 10),
          Text(zoneNames[i]),
          const Spacer(),
          Text("${db.round()} dB",
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E)),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _liveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      "LIVE",
      style: TextStyle(color: Colors.white),
    ),
  );
}