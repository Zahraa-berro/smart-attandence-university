class SensorReading {
  final String id;
  final String sensorId;
  final String classroomId;
  final double temperature;
  final int humidity;
  final int airQuality;
  final int noiseLevel;
  final int occupancy;
  final String classroomStatus;
  final List<String> alertsTriggered;
  final DateTime timestamp;

  SensorReading({
    required this.id,
    required this.sensorId,
    required this.classroomId,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
    required this.noiseLevel,
    required this.occupancy,
    required this.classroomStatus,
    required this.alertsTriggered,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['_id']?.toString() ?? '',
      sensorId: json['sensorId']?.toString() ?? '',
      classroomId: json['classroomId']?.toString() ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      airQuality: (json['airQuality'] as num?)?.toInt() ?? 0,
      noiseLevel: (json['noiseLevel'] as num?)?.toInt() ?? 0,
      occupancy: (json['occupancy'] as num?)?.toInt() ?? 0,
      classroomStatus: json['classroomStatus']?.toString() ?? 'unknown',
      alertsTriggered: (json['alertsTriggered'] as List<dynamic>? ?? [])
          .map((alert) => alert.toString())
          .toList(),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
