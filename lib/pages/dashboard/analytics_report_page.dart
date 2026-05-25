import 'package:flutter/material.dart';
import 'package:djatimobile_project/pages/dashboard/operator_detail_only.dart';
import 'package:djatimobile_project/pages/dashboard/vehicle_daily_log_page.dart';
import 'package:djatimobile_project/core/services/vehicle_daily_log_service.dart';

class AnalyticsReportPage extends StatefulWidget {
  const AnalyticsReportPage({super.key});

  @override
  State<AnalyticsReportPage> createState() => _AnalyticsReportPageState();
}

class _AnalyticsReportPageState extends State<AnalyticsReportPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await VehicleDailyLogService.getLogs();

      print("TOTAL VEHICLE DAILY LOGS DI UI: ${logs.length}");
      print("VEHICLE DAILY LOGS DATA: $logs");

      if (!mounted) return;

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatDecimal(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return "-";

    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return "$day-$month-$year";
    } catch (_) {
      return value;
    }
  }

  double get _totalHourMeter {
    if (_logs.isEmpty) return 0;

    double maxHourMeter = 0;

    for (final item in _logs) {
      final log = Map<String, dynamic>.from(item as Map);
      final hmEnd = _toDouble(log["hour_meter_end"]);

      if (hmEnd > maxHourMeter) {
        maxHourMeter = hmEnd;
      }
    }

    return maxHourMeter;
  }

  double get _totalFuelLiters {
    double total = 0;

    for (final item in _logs) {
      final log = Map<String, dynamic>.from(item as Map);
      total += _toDouble(log["fuel_liters"]);
    }

    return total;
  }

  double get _totalOperatingHours {
    double total = 0;

    for (final item in _logs) {
      final log = Map<String, dynamic>.from(item as Map);

      final start = _toDouble(log["hour_meter_start"]);
      final end = _toDouble(log["hour_meter_end"]);

      final diff = end - start;

      if (diff > 0) {
        total += diff;
      }
    }

    return total;
  }

  double get _avgFuelPerHour {
    if (_totalOperatingHours <= 0) return 0;
    return _totalFuelLiters / _totalOperatingHours;
  }

  int get _annualServiceCount {
    final now = DateTime.now();

    return _logs.where((item) {
      final log = Map<String, dynamic>.from(item as Map);
      final rawDate = log["log_date"]?.toString();

      if (rawDate == null || rawDate.isEmpty) return false;

      try {
        final date = DateTime.parse(rawDate).toLocal();
        return date.year == now.year;
      } catch (_) {
        return false;
      }
    }).length;
  }

  String _getUnitName(Map<String, dynamic> log) {
    final vehicle = log["vehicle"];

    if (vehicle is Map<String, dynamic>) {
      return vehicle["equipment_name"]?.toString() ?? "Unknown Unit";
    }

    return "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> log) {
    final vehicle = log["vehicle"];

    if (vehicle is Map<String, dynamic>) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getTrackingStatus(Map<String, dynamic> log) {
    final start = _toDouble(log["hour_meter_start"]);
    final end = _toDouble(log["hour_meter_end"]);
    final fuel = _toDouble(log["fuel_liters"]);

    if (end <= start) {
      return "Invalid HM";
    }

    if (fuel <= 0) {
      return "No Fuel";
    }

    return "Logged";
  }

  Color _getTrackingColor(String status) {
    switch (status.toLowerCase()) {
      case "logged":
        return Colors.green;
      case "invalid hm":
        return Colors.redAccent;
      case "no fuel":
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getTrackingInfo(Map<String, dynamic> log) {
    final start = _toDouble(log["hour_meter_start"]);
    final end = _toDouble(log["hour_meter_end"]);
    final fuel = _toDouble(log["fuel_liters"]);
    final operatingHours = end - start;

    final shift = log["shift"]?.toString();
    final logDate = log["log_date"]?.toString();

    final double fuelPerHour = operatingHours > 0 ? fuel / operatingHours : 0.0;

    final dateText = _formatDate(logDate);
    final shiftText = shift == null || shift.isEmpty ? "-" : shift;

    return "Date: $dateText | Shift: $shiftText | HM: ${_formatDecimal(end)} hrs | Fuel: ${_formatDecimal(fuelPerHour)} L/h";
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF9A825),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadLogs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                ),
                child: const Text(
                  "Coba Lagi",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fleet Performance Overview",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    "Total HM",
                    "${_formatDecimal(_totalHourMeter)} hrs",
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    "Avg Fuel",
                    "${_formatDecimal(_avgFuelPerHour)} L/h",
                    Icons.local_gas_station,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildWideInfoCard(
              "Annual Service",
              "$_annualServiceCount Logs This Year",
              Icons.build_circle,
              Colors.green,
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),

            const Text(
              "Unit Progress Tracking",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (_logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    "Belum ada daily unit log.",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ..._logs.map<Widget>((item) {
                final log = Map<String, dynamic>.from(item as Map);

                final unit = _getUnitName(log);
                final plate = _getPlateNumber(log);
                final status = _getTrackingStatus(log);
                final color = _getTrackingColor(status);
                final info = "${_getTrackingInfo(log)} | Plate: $plate";

                return _buildTrackingRow(
                  context,
                  unit,
                  status,
                  color,
                  info,
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingRow(
    BuildContext context,
    String unit,
    String status,
    Color color,
    String info,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OperatorDetailOnly(
                unit: unit,
                status: status,
                color: color,
                info: info,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "UNIT ANALYTICS",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFFF9A825),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VehicleDailyLogPage(),
                ),
              );

              _loadLogs();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}