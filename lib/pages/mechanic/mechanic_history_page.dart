/*
|--------------------------------------------------------------------------
| MECHANIC HISTORY PAGE
|--------------------------------------------------------------------------
|
| Penyesuaian utama:
| - Struktur halaman history tetap sama.
| - History tetap mengambil service_jobs?status=all.
| - Riwayat sparepart tetap ditampilkan.
| - Initial hour meter tidak ditimpa.
| - Teknisi input data terbaru hanya saat complete job di mechanic_flow.dart.
| - History hanya menampilkan hasil, tidak menginput ulang data maintenance.
| - Backend yang sebaiknya menghitung MA, MTTR, MTBF dan update vehicle.
|
*/

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';
import 'package:djatimobile_project/core/services/technician_part_usage_service.dart';

// -------------------------------------------------------------------
// 1. HALAMAN UTAMA: REPAIR / MAINTENANCE HISTORY TEKNISI
// -------------------------------------------------------------------
class MechanicHistoryPage extends StatefulWidget {
  const MechanicHistoryPage({super.key});

  @override
  State<MechanicHistoryPage> createState() => _MechanicHistoryPageState();
}

class _MechanicHistoryPageState extends State<MechanicHistoryPage> {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";

  bool _isLoading = true;
  String? _errorMessage;
  String? _partUsageError;

  List<dynamic> _jobs = [];
  List<dynamic> _partUsages = [];

  String _searchQuery = "";
  String _selectedFilter = "all";

  final List<String> _filters = const [
    "all",
    "completed",
    "in_progress",
    "ready",
  ];

  @override
  void initState() {
    super.initState();
    _loadServiceJobs();
  }

  Future<void> _loadServiceJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _partUsageError = null;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final response = await http.get(
        Uri.parse("$baseUrl/technician/service-jobs?status=all"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MECHANIC HISTORY STATUS: ${response.statusCode}");
      debugPrint("MECHANIC HISTORY BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = _safeJsonDecode(response.body);

        List<dynamic> jobs = [];

        if (decoded is List) {
          jobs = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final data = decoded["data"];

          if (data is List) {
            jobs = data;
          } else if (data is Map<String, dynamic> &&
              data["data"] is List) {
            jobs = data["data"];
          }
        }

        jobs.sort((a, b) {
          final aMap = (a is Map<String, dynamic>) ? a : (a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{});
          final bMap = (b is Map<String, dynamic>) ? b : (b is Map ? Map<String, dynamic>.from(b) : <String, dynamic>{});
          
          final aDateStr = aMap["updated_at"]?.toString() ?? aMap["created_at"]?.toString() ?? "";
          final bDateStr = bMap["updated_at"]?.toString() ?? bMap["created_at"]?.toString() ?? "";

          DateTime aDate = DateTime.fromMillisecondsSinceEpoch(0);
          DateTime bDate = DateTime.fromMillisecondsSinceEpoch(0);

          try { if (aDateStr.isNotEmpty) aDate = DateTime.parse(aDateStr); } catch (_) {}
          try { if (bDateStr.isNotEmpty) bDate = DateTime.parse(bDateStr); } catch (_) {}

          return bDate.compareTo(aDate);
        });

        List<dynamic> partUsages = [];

        try {
          partUsages =
              await TechnicianPartUsageService.getMyPartUsages();
        } catch (partError) {
          _partUsageError = partError
              .toString()
              .replaceFirst("Exception: ", "");
        }

        if (!mounted) return;

        setState(() {
          _jobs = jobs;
          _partUsages = partUsages;
          _isLoading = false;
        });
      } else {
        throw Exception(
          "Gagal mengambil history job teknisi: ${response.body}",
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
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

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> job) {
    return _asMap(job["damage_report"]) ??
        _asMap(job["damageReport"]) ??
        _asMap(job["report"]);
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> job) {
    final directVehicle = _asMap(job["vehicle"]);
    if (directVehicle != null) return directVehicle;

    final report = _getDamageReport(job);
    return _asMap(report?["vehicle"]);
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> job) {
    final directDriver = _asMap(job["driver"]);
    if (directDriver != null) return directDriver;

    final report = _getDamageReport(job);
    return _asMap(report?["driver"]);
  }

  int? _getDamageReportId(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    final rawId =
        job["damage_report_id"] ??
        job["damageReportId"] ??
        report?["id"];

    return int.tryParse(rawId?.toString() ?? "");
  }

  List<Map<String, dynamic>> _getPartUsagesForJob(
    Map<String, dynamic> job,
  ) {
    final damageReportId = _getDamageReportId(job);

    if (damageReportId == null || damageReportId <= 0) {
      return [];
    }

    return _partUsages
        .map((item) => _asMap(item))
        .whereType<Map<String, dynamic>>()
        .where((usage) {
      final rawId = usage["damage_report_id"] ??
          usage["damageReportId"] ??
          usage["damage_report"]?["id"] ??
          usage["damageReport"]?["id"];

      final usageDamageReportId =
          int.tryParse(rawId?.toString() ?? "");

      return usageDamageReportId == damageReportId;
    }).toList();
  }

  String _getUnitName(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    return "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDamageType(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    return report?["damage_type"]?.toString() ??
        job["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    return report?["description"]?.toString() ??
        job["description"]?.toString() ??
        "-";
  }

  String? _normalizeDamageImageUrl(dynamic value) {
    final raw = value?.toString().trim();

    if (raw == null || raw.isEmpty || raw == "null") {
      return null;
    }

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    var path = raw.replaceAll("\\", "/");

    if (path.startsWith("/storage/")) {
      return "https://proting3-backend-production.up.railway.app$path";
    }

    if (path.startsWith("storage/")) {
      return "https://proting3-backend-production.up.railway.app/$path";
    }

    if (path.startsWith("public/")) {
      path = path.replaceFirst("public/", "");
    }

    if (path.startsWith("/")) {
      path = path.substring(1);
    }

    return "https://proting3-backend-production.up.railway.app/storage/$path";
  }

  String? _getDamageImageUrl(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    final rawImage = report?["image_url"] ??
        report?["photo_url"] ??
        report?["damage_image_url"] ??
        report?["image"] ??
        report?["image_path"] ??
        report?["photo"] ??
        report?["damage_photo"] ??
        report?["picture"] ??
        report?["file_path"] ??
        job["image_url"] ??
        job["photo_url"] ??
        job["damage_image_url"] ??
        job["image"] ??
        job["image_path"] ??
        job["photo"] ??
        job["damage_photo"] ??
        job["picture"] ??
        job["file_path"];

    return _normalizeDamageImageUrl(rawImage);
  }

  void _openDamageImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "Gambar tidak dapat dimuat.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDriverName(Map<String, dynamic> job) {
    final driver = _getDriver(job);

    if (driver == null) {
      return "Unknown Driver";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "Unknown Driver";
  }

  String _formatNumber(dynamic value) {
    if (value == null) return "-";

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return "-";

    final number = double.tryParse(text.replaceAll(",", "."));

    if (number == null) return text;

    if (number % 1 == 0) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  dynamic _firstAvailableValue(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text != "null") {
        return value;
      }
    }

    return null;
  }

  String _getInitialHourMeter(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);
    final report = _getDamageReport(job);

    return _formatNumber(
      _firstAvailableValue([
        vehicle?["initial_hour_meter"],
        vehicle?["initial_kpi"],
        report?["vehicle_initial_hour_meter"],
        report?["vehicle_initial_kpi"],
        job["initial_hour_meter"],
        job["initial_kpi"],
      ]),
    );
  }

  String _getCurrentHourMeter(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);
    final report = _getDamageReport(job);

    return _formatNumber(
      _firstAvailableValue([
        job["final_hour_meter"],
        job["current_hour_meter"],
        job["latest_hour_meter"],
        vehicle?["current_hour_meter"],
        vehicle?["latest_hour_meter"],
        vehicle?["final_hour_meter"],
        report?["vehicle_current_hour_meter"],
        vehicle?["initial_hour_meter"],
        vehicle?["initial_kpi"],
      ]),
    );
  }

  String _getCurrentMa(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);

    final value = _firstAvailableValue([
      job["ma"],
      job["current_ma"],
      vehicle?["current_ma"],
      vehicle?["ma"],
      vehicle?["mechanical_availability"],
    ]);

    final formatted = _formatNumber(value);

    if (formatted == "-") return "-";

    return "$formatted%";
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final normalized = raw.contains(" ") && !raw.contains("T")
          ? raw.replaceFirst(" ", "T")
          : raw;

      final date = DateTime.parse(normalized).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return "$day-$month-$year $hour:$minute WIB";
    } catch (_) {
      return raw;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return "Ready to Start";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
        return "In Progress";

      case "completed":
      case "finished":
      case "selesai":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "requested":
        return "Requested";

      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "ready to start":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in_progress":
      case "in progress":
        return Colors.amber;

      case "completed":
      case "finished":
      case "selesai":
        return Colors.green;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Colors.redAccent;

      case "requested":
        return Colors.orange;

      default:
        return Colors.white54;
    }
  }

  Color _getPartUsageColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.redAccent;

      case "requested":
      case "pending":
        return Colors.orange;

      default:
        return Colors.white54;
    }
  }

  String _getPartUsageStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return "Approved";

      case "rejected":
        return "Rejected";

      case "requested":
      case "pending":
        return "Pending";

      default:
        return status;
    }
  }

  bool _isCompleted(Map<String, dynamic> job) {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" ||
        status == "finished" ||
        status == "selesai";
  }

  bool _isClosed(Map<String, dynamic> job) {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" ||
        status == "finished" ||
        status == "selesai" ||
        status == "canceled" ||
        status == "cancelled" ||
        status == "dibatalkan";
  }

  bool _isValidKpiValue(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return false;

    final number = double.tryParse(text);

    if (number == null) return false;

    return number > 0;
  }

  String _formatKpi(dynamic value, {int fractionDigits = 2}) {
    if (value == null) return "-";

    final number = double.tryParse(value.toString());

    if (number == null) return value.toString();

    return number.toStringAsFixed(fractionDigits);
  }

  List<String> _getRepairDetails(Map<String, dynamic> job) {
    final details = <String>[];

    final damageType = _getDamageType(job);
    final description = _getDescription(job);
    final status = _getStatusLabel(job["status"]?.toString() ?? "-");

    final scheduledAt = _formatDateTime(job["scheduled_at"]);
    final startedAt = _formatDateTime(job["started_at"]);
    final completedAt = _formatDateTime(job["completed_at"]);
    final estimatedFinishAt = _formatDateTime(job["estimated_finish_at"]);

    final noteDriver = job["note_driver"]?.toString() ?? "-";
    final noteAdmin = job["note_admin"]?.toString() ?? "-";
    final noteTechnician = job["note_technician"]?.toString() ?? "-";

    final initialHourMeter = _getInitialHourMeter(job);
    final currentHourMeter = _getCurrentHourMeter(job);
    final currentMa = _getCurrentMa(job);

    final totalRepairTime = _formatNumber(
      _firstAvailableValue([
        job["total_repair_time"],
        job["repair_time"],
        job["repair_time_hours"],
      ]),
    );

    final totalOperationalTime = _formatNumber(
      _firstAvailableValue([
        job["total_operational_time"],
        job["operational_time"],
        job["operational_time_hours"],
      ]),
    );

    final failureCount = _formatNumber(
      _firstAvailableValue([
        job["failure_count"],
        job["number_of_failures"],
        job["failures"],
      ]),
    );

    final actualOperatingHours = _formatNumber(
      _firstAvailableValue([
        job["actual_operating_hours"],
        job["actual_operation_hours"],
      ]),
    );

    final breakdownHours = _formatNumber(
      _firstAvailableValue([
        job["breakdown_hours"],
        job["breakdown_time"],
      ]),
    );

    if (damageType != "-") {
      details.add("Jenis kerusakan: $damageType");
    }

    if (description != "-") {
      details.add("Deskripsi driver: $description");
    }

    if (noteDriver != "-") {
      details.add("Catatan driver: $noteDriver");
    }

    if (scheduledAt != "-") {
      details.add("Jadwal admin: $scheduledAt");
    }

    if (estimatedFinishAt != "-") {
      details.add("Estimasi selesai: $estimatedFinishAt");
    }

    if (noteAdmin != "-") {
      details.add("Catatan admin: $noteAdmin");
    }

    if (initialHourMeter != "-") {
      details.add("Initial hour meter: $initialHourMeter");
    }

    if (currentHourMeter != "-") {
      details.add("Current hour meter: $currentHourMeter");
    }

    if (startedAt != "-") {
      details.add("Mulai dikerjakan: $startedAt");
    }

    if (completedAt != "-") {
      details.add("Selesai dikerjakan: $completedAt");
    }

    if (noteTechnician != "-") {
      details.add("Catatan teknisi: $noteTechnician");
    }

    if (totalRepairTime != "-") {
      details.add("Total repair time: $totalRepairTime jam");
    }

    if (totalOperationalTime != "-") {
      details.add("Total operational time: $totalOperationalTime jam");
    }

    if (failureCount != "-") {
      details.add("Number of failures: $failureCount");
    }

    if (actualOperatingHours != "-") {
      details.add("Actual operating hours: $actualOperatingHours jam");
    }

    if (breakdownHours != "-") {
      details.add("Breakdown hours: $breakdownHours jam");
    }

    if (_isValidKpiValue(job["mttr"])) {
      details.add("MTTR hasil backend: ${_formatKpi(job["mttr"])} hrs");
    }

    if (_isValidKpiValue(job["mtbf"])) {
      details.add("MTBF hasil backend: ${_formatKpi(job["mtbf"])} hrs");
    }

    if (_isValidKpiValue(job["ma"])) {
      details.add("MA hasil backend: ${_formatKpi(job["ma"], fractionDigits: 1)}%");
    } else if (currentMa != "-") {
      details.add("MA terbaru kendaraan: $currentMa");
    }

    details.add("Status akhir: $status");

    return details;
  }


  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "ready to start":
        return Icons.play_circle_outline_rounded;

      case "rescheduled":
        return Icons.update_rounded;

      case "in_progress":
      case "in progress":
        return Icons.autorenew_rounded;

      case "completed":
      case "finished":
      case "selesai":
        return Icons.check_circle_rounded;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Icons.cancel_rounded;

      case "requested":
        return Icons.hourglass_top_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  List<Map<String, dynamic>> get _mappedJobs {
    return _jobs
        .map((item) => _asMap(item))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  bool _matchesFilter(Map<String, dynamic> job) {
    if (_selectedFilter == "all") return true;

    final status = job["status"]?.toString().toLowerCase() ?? "";

    if (_selectedFilter == "completed") {
      return status == "completed" || status == "finished" || status == "selesai";
    }

    if (_selectedFilter == "in_progress") {
      return status == "in_progress";
    }

    if (_selectedFilter == "ready") {
      return status == "approved" || status == "scheduled" || status == "rescheduled";
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final keyword = _searchQuery.trim().toLowerCase();

    return _mappedJobs.where((job) {
      final unit = _getUnitName(job).toLowerCase();
      final plate = _getPlateNumber(job).toLowerCase();
      final driver = _getDriverName(job).toLowerCase();
      final damage = _getDamageType(job).toLowerCase();
      final status = _getStatusLabel(job["status"]?.toString() ?? "-").toLowerCase();

      final matchesSearch = keyword.isEmpty ||
          unit.contains(keyword) ||
          plate.contains(keyword) ||
          driver.contains(keyword) ||
          damage.contains(keyword) ||
          status.contains(keyword);

      return matchesSearch && _matchesFilter(job);
    }).toList();
  }

  int _countStatus(List<String> statuses) {
    return _mappedJobs.where((job) {
      final status = job["status"]?.toString().toLowerCase() ?? "";
      return statuses.contains(status);
    }).length;
  }

  String _filterLabel(String value) {
    switch (value) {
      case "all":
        return "All";
      case "completed":
        return "Completed";
      case "in_progress":
        return "Progress";
      case "ready":
        return "Ready";
      default:
        return value;
    }
  }

  Widget _buildHeaderDashboard() {
    final total = _mappedJobs.length;
    final completed = _countStatus(["completed", "finished", "selesai"]);
    final progress = _countStatus(["in_progress"]);
    final parts = _partUsages.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF9A825).withOpacity(0.30),
            const Color(0xFF1A1D24),
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFF9A825).withOpacity(0.20),
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
        children: [
          Row(
            children: [
              _iconBadge(
                icon: Icons.history_rounded,
                color: const Color(0xFFF9A825),
                size: 54,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Repair History",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Riwayat pekerjaan teknisi, hasil maintenance, dan request sparepart.",
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
                  title: "Total",
                  value: "$total",
                  icon: Icons.assignment_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  title: "Done",
                  value: "$completed",
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  title: "Progress",
                  value: "$progress",
                  icon: Icons.autorenew_rounded,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryTile(
                  title: "Parts",
                  value: "$parts",
                  icon: Icons.inventory_2_outlined,
                  color: Colors.lightBlueAccent,
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
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.075),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
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
      cursorColor: const Color(0xFFF9A825),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        hintText: "Cari unit, plat, driver, kerusakan, atau status...",
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
            color: const Color(0xFFF9A825).withOpacity(0.55),
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
                    ? const Color(0xFFF9A825).withOpacity(0.16)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFF9A825).withOpacity(0.65)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _filterLabel(filter),
                style: TextStyle(
                  color: selected ? const Color(0xFFF9A825) : Colors.white54,
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

  Widget _buildHistoryCard(Map<String, dynamic> job) {
    final bookingId = job["id"]?.toString() ?? "-";
    final reportId = job["damage_report_id"]?.toString() ??
        _getDamageReport(job)?["id"]?.toString() ??
        "-";

    final unitName = _getUnitName(job);
    final plateNumber = _getPlateNumber(job);
    final driverName = _getDriverName(job);
    final damageType = _getDamageType(job);

    final statusRaw = job["status"]?.toString() ?? "-";
    final status = _getStatusLabel(statusRaw);
    final statusColor = _getStatusColor(statusRaw);

    final scheduledAt = _formatDateTime(job["scheduled_at"]);
    final completedAt = _formatDateTime(job["completed_at"]);

    final repairDetails = _getRepairDetails(job);
    final isCompleted = _isCompleted(job);
    final isClosed = _isClosed(job);
    final partUsages = _getPartUsagesForJob(job);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          collapsedIconColor: Colors.white38,
          iconColor: const Color(0xFFF9A825),
          leading: _iconBadge(
            icon: _getStatusIcon(statusRaw),
            color: statusColor,
            size: 46,
          ),
          title: Text(
            unitName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$plateNumber • Driver: $driverName",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "#BK-$bookingId • #DR-$reportId",
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _statusChip(status, statusColor),
                    _miniChip("Damage: $damageType"),
                    if (completedAt != "-") _miniChip("Completed: $completedAt"),
                    if (scheduledAt != "-") _miniChip("Schedule: $scheduledAt"),
                  ],
                ),
              ],
            ),
          ),
          trailing: isCompleted
              ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
              : Icon(
                  isClosed ? Icons.block_rounded : Icons.pending_actions_rounded,
                  color: statusColor,
                ),
          children: [
            _sectionCard(
              title: "Damage Report",
              icon: Icons.report_problem_outlined,
              child: Column(
                children: [
                  _textBlock(
                    title: "Jenis Kerusakan",
                    value: damageType,
                    icon: Icons.build_circle_outlined,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 10),
                  _textBlock(
                    title: "Foto Kerusakan",
                    value: "Tap gambar untuk melihat ukuran penuh.",
                    icon: Icons.photo_camera_outlined,
                    color: Colors.white70,
                    child: _buildDamageImageSection(job),
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: "Maintenance Details",
              icon: Icons.fact_check_outlined,
              child: Column(
                children: repairDetails.map((detail) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _buildInfoRow(
                      icon: Icons.check_circle_outline_rounded,
                      text: detail,
                    ),
                  );
                }).toList(),
              ),
            ),
            _sectionCard(
              title: "Sparepart Requests",
              icon: Icons.inventory_2_outlined,
              child: _buildPartUsageSection(partUsages),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20242D).withOpacity(0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.065),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFF9A825), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFF9A825),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textBlock({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child,
          ],
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
        border: Border.all(color: color.withOpacity(0.30)),
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

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }

  Widget _buildNoDataFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
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
            "History tidak ditemukan",
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
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D24),
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
                  "Gagal memuat repair history",
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
                    onPressed: _loadServiceJobs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9A825),
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

    if (_jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadServiceJobs,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1A1D24),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            _iconBadge(
              icon: Icons.history_rounded,
              color: const Color(0xFFF9A825),
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              "Belum ada history maintenance",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "History akan muncul setelah admin menjadwalkan dan teknisi memproses job.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    final jobs = _filteredJobs;

    return RefreshIndicator(
      onRefresh: _loadServiceJobs,
      color: const Color(0xFFF9A825),
      backgroundColor: const Color(0xFF1A1D24),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _buildHeaderDashboard(),
          const SizedBox(height: 16),
          _buildSearchBox(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          if (_partUsageError != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.25),
                ),
              ),
              child: Text(
                "Riwayat sparepart belum bisa dimuat: $_partUsageError",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (jobs.isEmpty)
            _buildNoDataFound()
          else
            ...jobs.map((job) => _buildHistoryCard(job)),
        ],
      ),
    );
  }

  Widget _buildDamageImageSection(Map<String, dynamic> job) {
    final imageUrl = _getDamageImageUrl(job);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Foto Kerusakan:",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (imageUrl == null)
          Container(
            width: double.infinity,
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.035),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity( 0.06),
              ),
            ),
            child: const Text(
              "Foto kerusakan belum tersedia.",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () => _openDamageImagePreview(imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Container(
                        width: double.infinity,
                        height: 170,
                        alignment: Alignment.center,
                        color: Colors.white.withOpacity( 0.04),
                        child: const CircularProgressIndicator(
                          color: Color(0xFFF9A825),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 130,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.035),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity( 0.06),
                          ),
                        ),
                        child: const Text(
                          "Gambar tidak dapat dimuat.",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity( 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Tap to view",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPartUsageSection(
    List<Map<String, dynamic>> partUsages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sparepart Requests:",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (partUsages.isEmpty)
          _buildInfoRow(
            icon: Icons.inventory_2_outlined,
            text: "Belum ada request sparepart untuk job ini.",
          )
        else
          ...partUsages.map((usage) {
            final part = _asMap(usage["part"]);
            final partName = part?["name"]?.toString() ?? "-";
            final partSku = part?["sku"]?.toString() ?? "-";
            final qty = usage["qty"]?.toString() ?? "0";
            final statusRaw = usage["status"]?.toString() ?? "requested";
            final status = _getPartUsageStatusLabel(statusRaw);
            final color = _getPartUsageColor(statusRaw);
            final createdAt = _formatDateTime(usage["created_at"]);
            final note = usage["note"]?.toString() ?? "-";

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity( 0.035),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity( 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$partSku — $partName",
                    style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _smallText("Qty: $qty"),
                  _smallText("Status: $status", color: color),
                  if (createdAt != "-") _smallText("Requested: $createdAt"),
                  if (note != "-") _smallText("Note: $note"),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _smallText(
    String text, {
    Color color = Colors.white54,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFF9A825),
          size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Repair History",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadServiceJobs,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFF9A825),
            ),
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

