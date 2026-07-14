import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/sensor_reading.dart';
import '../../services/api_service.dart';

class AirQualityScreen extends StatefulWidget {
  const AirQualityScreen({super.key});

  @override
  State<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Timer _sensorTimer;
  final ApiService _apiService = ApiService();

  // Sensor values
  double _aqi = 42.0;
  double _humidity = 58.0;
  double _temperature = 23.5;
  double _noiseLevel = 32.0;
  double _occupancy = 0.0;
  SensorReading? _latestReading;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _loadLatestSensorReading();
    _sensorTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLatestSensorReading(showLoading: false);
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _sensorTimer.cancel();
    super.dispose();
  }

  Future<void> _loadLatestSensorReading({bool showLoading = true}) async {
    debugPrint(
      'AirQualityScreen: fetching latest sensor readings from backend',
    );

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final readings = await _apiService.getLatestSensorReadings();
      debugPrint(
        'AirQualityScreen: received ${readings.length} sensor readings',
      );
      if (!mounted) return;

      if (readings.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No sensor data found. Generate a reading first.";
        });
        return;
      }

      final reading = readings.first;
      setState(() {
        _latestReading = reading;
        _aqi = reading.airQuality.toDouble();
        _humidity = reading.humidity.toDouble();
        _temperature = reading.temperature;
        _noiseLevel = reading.noiseLevel.toDouble();
        _occupancy = reading.occupancy.toDouble();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      debugPrint('AirQualityScreen: sensor fetch error: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  // ── Color / label helpers ─────────────────────────────────────────────────

  Color _aqiColor(double aqi) {
    if (aqi <= 50) return const Color(0xFF1D9E75);
    if (aqi <= 100) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _aqiLabel(double aqi) {
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    return "Unhealthy";
  }

  Color _humidityColor(double h) {
    if (h >= 40 && h <= 70) return const Color(0xFF1D9E75);
    if (h < 30 || h > 80) return const Color(0xFFD85A30);
    return const Color(0xFFEF9F27);
  }

  String _humidityLabel(double h) {
    if (h < 30) return "Too Dry";
    if (h > 70) return "Too Humid";
    return "Comfortable";
  }

  Color _noiseColor(double noiseLevel) {
    if (noiseLevel < 55) return const Color(0xFF1D9E75);
    if (noiseLevel < 80) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _noiseLabel(double noiseLevel) {
    if (noiseLevel < 55) return "Normal";
    if (noiseLevel < 80) return "Moderate";
    return "High";
  }

  Color _occupancyColor(double occupancy) {
    if (occupancy <= 25) return const Color(0xFF1D9E75);
    if (occupancy <= 35) return const Color(0xFFEF9F27);
    return const Color(0xFFD85A30);
  }

  String _occupancyLabel(double occupancy) {
    if (occupancy <= 25) return "Comfortable";
    if (occupancy <= 35) return "Busy";
    return "Crowded";
  }

  // ── Pie chart helpers ─────────────────────────────────────────────────────

  List<double> _pieValues() {
    return [
      (_humidity / 90 * 100).clamp(0, 100),
      ((_temperature - 15) / 20 * 100).clamp(0, 100),
      (_noiseLevel / 100 * 100).clamp(0, 100),
      (_occupancy / 40 * 100).clamp(0, 100),
      (_aqi / 150 * 100).clamp(0, 100),
    ];
  }

  String _dominantLabel() {
    final labels = ["Humidity", "Temp", "Noise", "Occupancy", "AQI"];
    final values = _pieValues();
    int maxIdx = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[maxIdx]) maxIdx = i;
    }
    return labels[maxIdx];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          // Gradient header background
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _aqiColor(_aqi).withOpacity(0.85),
                  _aqiColor(_aqi),
                  _aqiColor(_aqi).withOpacity(0.60),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative circle
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
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
                      const Text(
                        "Air Quality",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _liveBadge(),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => _loadLatestSensorReading(),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                ),

                // ── AQI hero ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _animCtrl,
                              builder: (_, __) => CircularProgressIndicator(
                                value: _animCtrl.value * (_aqi / 150),
                                strokeWidth: 7,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${_aqi.round()}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Text(
                                  "AQI",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _aqiLabel(_aqi),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Air Quality Index",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _latestReading == null
                                ? "Waiting for sensor data"
                                : "${_latestReading!.classroomId} - ${_latestReading!.sensorId}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.60),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // ── White sheet ───────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Classroom Conditions grid ─────────────────
                          if (_errorMessage != null) ...[
                            _statusCard(
                              icon: Icons.error_outline_rounded,
                              title: "Sensor data unavailable",
                              message: _errorMessage!,
                              color: const Color(0xFFD85A30),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_isLoading && _latestReading == null) ...[
                            _statusCard(
                              icon: Icons.sync_rounded,
                              title: "Loading sensor data",
                              message: "Fetching latest classroom reading...",
                              color: const Color(0xFF5B8DEF),
                            ),
                            const SizedBox(height: 16),
                          ] else if (_latestReading != null) ...[
                            _statusCard(
                              icon: Icons.sensors_rounded,
                              title: "Classroom ${_latestReading!.classroomId}",
                              message:
                                  "Status: ${_latestReading!.classroomStatus} | Occupancy: ${_latestReading!.occupancy}/40",
                              color: _aqiColor(_aqi),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _sectionTitle("Classroom Conditions"),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _statCard(
                                icon: Icons.water_drop_outlined,
                                label: "Humidity",
                                value: "${_humidity.toStringAsFixed(1)}%",
                                sub: _humidityLabel(_humidity),
                                color: _humidityColor(_humidity),
                              ),
                              const SizedBox(width: 10),
                              _statCard(
                                icon: Icons.thermostat_outlined,
                                label: "Temperature",
                                value: "${_temperature.toStringAsFixed(1)}°C",
                                sub: _temperature < 20
                                    ? "Cool"
                                    : _temperature < 27
                                    ? "Comfortable"
                                    : "Warm",
                                color: _temperature < 20
                                    ? const Color(0xFF5B8DEF)
                                    : _temperature < 27
                                    ? const Color(0xFF1D9E75)
                                    : const Color(0xFFD85A30),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statCard(
                                icon: Icons.volume_up_outlined,
                                label: "Noise",
                                value: "${_noiseLevel.round()} dB",
                                sub: _noiseLabel(_noiseLevel),
                                color: _noiseColor(_noiseLevel),
                              ),
                              const SizedBox(width: 10),
                              _statCard(
                                icon: Icons.groups_2_outlined,
                                label: "Occupancy",
                                value: "${_occupancy.round()} / 40",
                                sub: _occupancyLabel(_occupancy),
                                color: _occupancyColor(_occupancy),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Sensor Breakdown Pie Chart ────────────────
                          _sectionTitle("Sensor Breakdown"),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "% of max safe threshold used per sensor",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF888780),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: CustomPaint(
                                    painter: _PieChartPainter(
                                      values: _pieValues(),
                                      colors: const [
                                        Color(0xFF1D9E75), // humidity
                                        Color(0xFF5B8DEF), // temperature
                                        Color(0xFFEF9F27), // noise
                                        Color(0xFFD85A30), // occupancy
                                        Color(0xFF9B2335), // AQI
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _dominantLabel(),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1A1A2E),
                                            ),
                                          ),
                                          const Text(
                                            "Dominant",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF888780),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Legend
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _legendDot(
                                      const Color(0xFF1D9E75),
                                      "Humidity",
                                      "${(_humidity / 90 * 100).round()}%",
                                    ),
                                    _legendDot(
                                      const Color(0xFF5B8DEF),
                                      "Temp",
                                      "${((_temperature - 15) / 20 * 100).round()}%",
                                    ),
                                    _legendDot(
                                      const Color(0xFFEF9F27),
                                      "Noise",
                                      "${(_noiseLevel / 100 * 100).round()}%",
                                    ),
                                    _legendDot(
                                      const Color(0xFFD85A30),
                                      "Occupancy",
                                      "${(_occupancy / 40 * 100).round()}%",
                                    ),
                                    _legendDot(
                                      const Color(0xFF9B2335),
                                      "AQI",
                                      "${(_aqi / 150 * 100).round()}%",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Humidity detail ───────────────────────────
                          _sectionTitle("Humidity — الرطوبة"),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Relative Humidity",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF444441),
                                      ),
                                    ),
                                    Text(
                                      "${_humidity.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: _humidityColor(_humidity),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Humidity bar with zones
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 30,
                                            child: Container(
                                              height: 18,
                                              color: const Color(
                                                0xFFD85A30,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 40,
                                            child: Container(
                                              height: 18,
                                              color: const Color(
                                                0xFF1D9E75,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 30,
                                            child: Container(
                                              height: 18,
                                              color: const Color(
                                                0xFFD85A30,
                                              ).withOpacity(0.15),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      left:
                                          (_humidity / 100) *
                                          (MediaQuery.of(context).size.width -
                                              72),
                                      child: Container(
                                        width: 4,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: _humidityColor(_humidity),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Too dry (< 30%)",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(
                                          0xFFD85A30,
                                        ).withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      "Ideal: 40–70%",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(
                                          0xFF1D9E75,
                                        ).withOpacity(0.8),
                                      ),
                                    ),
                                    Text(
                                      "Too humid",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(
                                          0xFFD85A30,
                                        ).withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _humidityColor(
                                      _humidity,
                                    ).withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: _humidityColor(_humidity),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _humidity < 30
                                              ? "Humidity is low. May cause dry throat and reduced focus."
                                              : _humidity > 70
                                              ? "Humidity is high. May promote mold and discomfort."
                                              : "Humidity is in the comfortable range for learning.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _humidityColor(_humidity),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Noise detail ───────────────────────────────
                          _sectionTitle("Noise Level"),
                          const SizedBox(height: 12),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Classroom Noise",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF444441),
                                      ),
                                    ),
                                    Text(
                                      "${_noiseLevel.round()} dB",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: _noiseColor(_noiseLevel),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (_noiseLevel / 100).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFF1EFE8),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _noiseColor(_noiseLevel),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "30 dB",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(0xFF888780),
                                      ),
                                    ),
                                    Text(
                                      "55",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(0xFF888780),
                                      ),
                                    ),
                                    Text(
                                      "80+",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: const Color(0xFF888780),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── AQI Scale ─────────────────────────────────
                          _sectionTitle("AQI Scale"),
                          const SizedBox(height: 12),
                          _aqiScaleCard(),
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

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
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
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
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
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          "$label $value",
          style: const TextStyle(fontSize: 11, color: Color(0xFF888780)),
        ),
      ],
    );
  }

  Widget _aqiScaleCard() {
    final levels = [
      ("0–50", "Good", const Color(0xFF1D9E75)),
      ("51–100", "Moderate", const Color(0xFFEF9F27)),
      ("101–150", "Unhealthy for sensitive", const Color(0xFFD85A30)),
      ("151+", "Unhealthy", const Color(0xFF9B2335)),
    ];
    return _card(
      child: Column(
        children: levels.map((l) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 22,
                  decoration: BoxDecoration(
                    color: l.$3.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: l.$3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l.$2,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444441),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _liveBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.20),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Icon(Icons.circle, size: 8, color: Color(0xFF1D9E75)),
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
}

// ── Pie chart painter ─────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 10;
    final holeRadius = radius * 0.52;

    double startAngle = -pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + 0.02,
        sweep - 0.04,
        true,
        paint,
      );

      startAngle += sweep;
    }

    // Donut hole
    canvas.drawCircle(center, holeRadius, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.values != values || old.colors != colors;
}
