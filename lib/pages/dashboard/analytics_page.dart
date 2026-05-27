import 'package:flutter/material.dart';
import 'package:djatimobile_project/core/services/analytics_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  String? _errorMessage;

  double _totalHourMeter = 0;
  int _annualServiceCount = 0;
  double _fuelConsumptionLiters = 0;

  Map<String, dynamic>? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AnalyticsService.getDriverAnalytics();

      print("ANALYTICS DATA DI UI: $data");

      if (!mounted) return;

      setState(() {
        _vehicle = data["vehicle"] is Map<String, dynamic>
            ? data["vehicle"] as Map<String, dynamic>
            : null;

        _totalHourMeter =
            double.tryParse(data["total_hour_meter"].toString()) ?? 0;

        _annualServiceCount =
            int.tryParse(data["annual_service_count"].toString()) ?? 0;

        _fuelConsumptionLiters =
            double.tryParse(data["fuel_consumption_liters"].toString()) ?? 0;

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

  String get _unitName {
    return _vehicle?["equipment_name"]?.toString() ?? "Assigned Vehicle";
  }

  String get _plateNumber {
    return _vehicle?["plate_number"]?.toString() ?? "-";
  }

  String _formatDecimal(double value) {
    return value.toStringAsFixed(2);
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
                onPressed: _loadAnalytics,
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
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildVehicleCard(),

            const SizedBox(height: 20),

            _buildStatCard(
              title: "Total Hour Meter",
              value: "${_formatDecimal(_totalHourMeter)} HRS",
              icon: Icons.timer,
            ),
            _buildStatCard(
              title: "Annual Service",
              value: "$_annualServiceCount Times",
              icon: Icons.settings,
            ),
            _buildStatCard(
              title: "Fuel Consumption",
              value: "${_formatDecimal(_fuelConsumptionLiters)} Liters",
              icon: Icons.local_gas_station,
            ),

            const SizedBox(height: 20),

            _buildChartPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF9A825).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Assigned Vehicle",
            style: TextStyle(
              color: Color(0xFFF9A825),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _unitName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Plate Number: $_plateNumber",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: const Center(
        child: Text(
          "Monthly Activity Chart",
          style: TextStyle(
            color: Colors.white24,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFF9A825),
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
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Analytics",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}