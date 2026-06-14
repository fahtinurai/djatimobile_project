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
  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _logs = [];

  String _searchQuery = "";
  String _selectedFilter = "all";

  final List<String> _filters = const [
    "all",
    "logged",
    "invalid_hm",
    "no_fuel",
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final logs = await VehicleDailyLogService.getLogs();

      debugPrint("TOTAL VEHICLE DAILY LOGS DI UI: ${logs.length}");
      debugPrint("VEHICLE DAILY LOGS DATA: $logs");

      final safeLogs = logs
          .map((item) => _asMap(item))
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) return;

      setState(() {
        _logs = safeLogs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    final raw = value.toString().trim().replaceAll(",", ".");

    return double.tryParse(raw) ?? 0;
  }

  String _formatDecimal(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty || value == "null") return "-";

    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();

      return "$day-$month-$year";
    } catch (_) {
      return value;
    }
  }

  double get _totalHourMeter {
    if (_logs.isEmpty) return 0;

    double maxHourMeter = 0;

    for (final log in _logs) {
      final hmEnd = _toDouble(log["hour_meter_end"]);

      if (hmEnd > maxHourMeter) {
        maxHourMeter = hmEnd;
      }
    }

    return maxHourMeter;
  }

  double get _totalFuelLiters {
    double total = 0;

    for (final log in _logs) {
      total += _toDouble(log["fuel_liters"]);
    }

    return total;
  }

  double get _totalOperatingHours {
    double total = 0;

    for (final log in _logs) {
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

    return _logs.where((log) {
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

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> log) {
    return _asMap(log["vehicle"]);
  }

  String _getUnitName(Map<String, dynamic> log) {
    final vehicle = _getVehicle(log);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    return "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> log) {
    final vehicle = _getVehicle(log);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getShift(Map<String, dynamic> log) {
    final shift = log["shift"]?.toString();

    if (shift == null || shift.isEmpty || shift == "null") {
      return "-";
    }

    return shift;
  }

  double _getOperatingHours(Map<String, dynamic> log) {
    final start = _toDouble(log["hour_meter_start"]);
    final end = _toDouble(log["hour_meter_end"]);
    final diff = end - start;

    if (diff <= 0) return 0;

    return diff;
  }

  double _getFuelPerHour(Map<String, dynamic> log) {
    final operatingHours = _getOperatingHours(log);
    final fuel = _toDouble(log["fuel_liters"]);

    if (operatingHours <= 0) return 0;

    return fuel / operatingHours;
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
        return Colors.greenAccent;

      case "invalid hm":
        return Colors.redAccent;

      case "no fuel":
        return Colors.orangeAccent;

      default:
        return Colors.lightBlueAccent;
    }
  }

  IconData _getTrackingIcon(String status) {
    switch (status.toLowerCase()) {
      case "logged":
        return Icons.check_circle_rounded;

      case "invalid hm":
        return Icons.warning_amber_rounded;

      case "no fuel":
        return Icons.local_gas_station_outlined;

      default:
        return Icons.info_outline_rounded;
    }
  }

  String _getTrackingInfo(Map<String, dynamic> log) {
    final end = _toDouble(log["hour_meter_end"]);
    final fuelPerHour = _getFuelPerHour(log);
    final shift = _getShift(log);
    final logDate = log["log_date"]?.toString();

    final dateText = _formatDate(logDate);

    return "Date: $dateText | Shift: $shift | HM: ${_formatDecimal(end)} hrs | Fuel: ${_formatDecimal(fuelPerHour)} L/h";
  }

  bool _matchesFilter(Map<String, dynamic> log) {
    if (_selectedFilter == "all") return true;

    final status = _getTrackingStatus(log).toLowerCase();

    if (_selectedFilter == "logged") {
      return status == "logged";
    }

    if (_selectedFilter == "invalid_hm") {
      return status == "invalid hm";
    }

    if (_selectedFilter == "no_fuel") {
      return status == "no fuel";
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final keyword = _searchQuery.trim().toLowerCase();

    return _logs.where((log) {
      final unit = _getUnitName(log).toLowerCase();
      final plate = _getPlateNumber(log).toLowerCase();
      final status = _getTrackingStatus(log).toLowerCase();
      final shift = _getShift(log).toLowerCase();

      final matchSearch = keyword.isEmpty ||
          unit.contains(keyword) ||
          plate.contains(keyword) ||
          status.contains(keyword) ||
          shift.contains(keyword);

      return matchSearch && _matchesFilter(log);
    }).toList();
  }

  int _countStatus(String targetStatus) {
    return _logs.where((log) {
      return _getTrackingStatus(log).toLowerCase() ==
          targetStatus.toLowerCase();
    }).length;
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final filteredLogs = _filteredLogs;

    return RefreshIndicator(
      onRefresh: _loadLogs,
      color: primaryColor,
      backgroundColor: cardColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeaderDashboard(),
          const SizedBox(height: 16),
          _buildSearchBox(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 18),
          _buildSectionHeader(
            title: "Unit Progress Tracking",
            subtitle: "Daftar aktivitas harian unit berdasarkan log operator.",
          ),
          const SizedBox(height: 14),
          if (_logs.isEmpty)
            _buildEmptyState()
          else if (filteredLogs.isEmpty)
            _buildNoDataFound()
          else
            ...filteredLogs.map((log) {
              final unit = _getUnitName(log);
              final plate = _getPlateNumber(log);
              final status = _getTrackingStatus(log);
              final color = _getTrackingColor(status);
              final info = "${_getTrackingInfo(log)} | Plate: $plate";

              return _buildTrackingCard(
                context: context,
                log: log,
                unit: unit,
                plate: plate,
                status: status,
                color: color,
                info: info,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeaderDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.30),
            cardColor,
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: primaryColor.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(
                icon: Icons.analytics_outlined,
                color: primaryColor,
                size: 52,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fleet Analytics",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Monitoring performa unit, HM, fuel, dan log operator.",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.35,
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
              Expanded(
                child: _summaryTile(
                  title: "Total HM",
                  value: "${_formatDecimal(_totalHourMeter)}",
                  unit: "hrs",
                  icon: Icons.timer_outlined,
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  title: "Avg Fuel",
                  value: _formatDecimal(_avgFuelPerHour),
                  unit: "L/h",
                  icon: Icons.local_gas_station_outlined,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  title: "Ops Hours",
                  value: _formatDecimal(_totalOperatingHours),
                  unit: "hrs",
                  icon: Icons.av_timer_outlined,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  title: "Logs Year",
                  value: "$_annualServiceCount",
                  unit: "logs",
                  icon: Icons.build_circle_outlined,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.075),
        ),
      ),
      child: Row(
        children: [
          _iconBadge(
            icon: icon,
            color: color,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: " $unit",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      cursorColor: primaryColor,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        hintText: "Cari unit, plat, shift, atau status...",
        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 12,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.white38,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: primaryColor.withOpacity(0.55),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = filter == _selectedFilter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected
                    ? primaryColor.withOpacity(0.16)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? primaryColor.withOpacity(0.65)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _filterLabel(filter),
                style: TextStyle(
                  color: selected ? primaryColor : Colors.white54,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _filterLabel(String value) {
    switch (value) {
      case "all":
        return "All";
      case "logged":
        return "Logged";
      case "invalid_hm":
        return "Invalid HM";
      case "no_fuel":
        return "No Fuel";
      default:
        return value;
    }
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconBadge(
          icon: Icons.route_outlined,
          color: primaryColor,
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingCard({
    required BuildContext context,
    required Map<String, dynamic> log,
    required String unit,
    required String plate,
    required String status,
    required Color color,
    required String info,
  }) {
    final start = _toDouble(log["hour_meter_start"]);
    final end = _toDouble(log["hour_meter_end"]);
    final fuel = _toDouble(log["fuel_liters"]);
    final operatingHours = _getOperatingHours(log);
    final fuelPerHour = _getFuelPerHour(log);
    final date = _formatDate(log["log_date"]?.toString());
    final shift = _getShift(log);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 15,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _iconBadge(
                    icon: _getTrackingIcon(status),
                    color: color,
                    size: 48,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$plate • $date • Shift $shift",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _statusChip(status, color),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _miniMetric(
                      title: "HM Start",
                      value: _formatDecimal(start),
                      icon: Icons.play_arrow_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniMetric(
                      title: "HM End",
                      value: _formatDecimal(end),
                      icon: Icons.flag_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniMetric(
                      title: "Ops",
                      value: _formatDecimal(operatingHours),
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _miniMetric(
                      title: "Fuel",
                      value: "${_formatDecimal(fuel)} L",
                      icon: Icons.local_gas_station_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniMetric(
                      title: "Fuel / Hour",
                      value: "${_formatDecimal(fuelPerHour)} L/h",
                      icon: Icons.speed_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniMetric(
                      title: "Detail",
                      value: "Open",
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.055),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 16,
          ),
          const SizedBox(height: 7),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBadge(
                icon: Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 58,
              ),
              const SizedBox(height: 16),
              const Text(
                "Gagal memuat data",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _loadLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    "Coba Lagi",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          _iconBadge(
            icon: Icons.assignment_late_outlined,
            color: primaryColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum ada daily unit log",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Data akan muncul setelah operator menambahkan log harian kendaraan.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          _iconBadge(
            icon: Icons.search_off_rounded,
            color: Colors.white38,
            size: 58,
          ),
          const SizedBox(height: 14),
          const Text(
            "Data tidak ditemukan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Coba ubah kata kunci pencarian atau filter status.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.30),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _iconBadge({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }

  Future<void> _openDailyLogPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VehicleDailyLogPage(),
      ),
    );

    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Unit Analytics",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Tambah Daily Log",
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: primaryColor,
            ),
            onPressed: _openDailyLogPage,
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
            ),
            onPressed: _loadLogs,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F1115),
              Color(0xFF111827),
              Color(0xFF0F1115),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }
}