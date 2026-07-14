import 'package:flutter/material.dart';
import 'package:smart_classroom_new/services/api_service.dart';

class AdminSensorOverviewScreen extends StatefulWidget {
  const AdminSensorOverviewScreen({super.key});

  @override
  State<AdminSensorOverviewScreen> createState() => _AdminSensorOverviewScreenState();
}

class _AdminSensorOverviewScreenState extends State<AdminSensorOverviewScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _overview;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final overview = await _apiService.getAdminSensorOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Sensor Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOverview,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _overview == null
                  ? const Center(child: Text('No sensor overview data available.'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildOverviewHeader(),
                        const SizedBox(height: 16),
                        _buildStatusCards(),
                        const SizedBox(height: 16),
                        _buildMetricCards(),
                        const SizedBox(height: 16),
                        _buildDetailCard(),
                      ],
                    ),
    );
  }

  Widget _buildOverviewHeader() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Campus IoT Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Classroom sensors updated at ${_formatTimestamp(_overview?['latestTimestamp'])}'),
            const SizedBox(height: 12),
            Text(
              '${_overview?['latestReadingsCount'] ?? 0} classrooms monitored',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    final statusItems = [
      _StatusBadge('Good', _overview?['goodClassrooms']?.toString() ?? '0', Colors.green),
      _StatusBadge('Moderate', _overview?['moderateClassrooms']?.toString() ?? '0', Colors.orange),
      _StatusBadge('Critical', _overview?['criticalClassrooms']?.toString() ?? '0', Colors.red),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: statusItems
          .map(
            (item) => Container(
              width: (MediaQuery.of(context).size.width - 56) / 3,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.backgroundColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.backgroundColor.withOpacity(0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: TextStyle(color: item.backgroundColor, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(item.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: item.backgroundColor)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMetricCards() {
    final metricItems = [
      _MetricBadge('Temp', '${_overview?['averageTemperature'] ?? 0}°C'),
      _MetricBadge('Humidity', '${_overview?['averageHumidity'] ?? 0}%'),
      _MetricBadge('Air Quality', '${_overview?['averageAirQuality'] ?? 0}'),
      _MetricBadge('Noise', '${_overview?['averageNoiseLevel'] ?? 0} dB'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metricItems
          .map(
            (item) => Container(
              width: (MediaQuery.of(context).size.width - 56) / 2,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDetailCard() {
    final mostCritical = _overview?['mostCriticalClassroom']?.toString() ?? 'No critical rooms';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Critical Insight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Most critical classroom: $mostCritical'),
            const SizedBox(height: 8),
            const Text('Use this screen to track sensor health across classrooms and react faster to critical alerts.'),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return 'unknown';
    try {
      final ts = value.toString();
      return ts;
    } catch (_) {
      return value.toString();
    }
  }
}

class _StatusBadge {
  final String label;
  final String value;
  final Color backgroundColor;

  _StatusBadge(this.label, this.value, this.backgroundColor);
}

class _MetricBadge {
  final String label;
  final String value;

  _MetricBadge(this.label, this.value);
}
