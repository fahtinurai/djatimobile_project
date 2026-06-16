/*
|--------------------------------------------------------------------------
| MECHANIC FLOW
|--------------------------------------------------------------------------
|
| Penyesuaian utama:
| - Struktur halaman tetap sama seperti file sebelumnya.
| - Teknisi tetap mengambil job dari service_bookings.
| - Teknisi tetap bisa START JOB, COMPLETE JOB, dan REQUEST SPAREPART.
| - Saat COMPLETE JOB, teknisi mengirim data mentah ke backend.
| - initial_hour_meter tidak ditimpa oleh teknisi.
| - backend yang sebaiknya update current_hour_meter/current_ma dan hitung MA.
|
*/

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';
import 'package:djatimobile_project/core/services/technician_part_usage_service.dart';

class MechanicTasksFlow extends StatelessWidget {
  const MechanicTasksFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return const MechanicTasksPage();
  }
}

// -------------------------------------------------------------------
// SCREEN 1: TASKS LIST DARI SERVICE BOOKINGS UNTUK TEKNISI
// -------------------------------------------------------------------
class MechanicTasksPage extends StatefulWidget {
  const MechanicTasksPage({super.key});

  @override
  State<MechanicTasksPage> createState() => _MechanicTasksPageState();
}

class _MechanicTasksPageState extends State<MechanicTasksPage> {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _jobs = [];

  String _searchQuery = "";
  String _selectedFilter = "all";

  final List<String> _filters = const [
    "all",
    "ready",
    "in_progress",
    "completed",
    "canceled",
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
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

  List<dynamic> _parseJobList(String body) {
    final decoded = _safeJsonDecode(body);

    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded["data"];

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic>) {
        final nestedData = data["data"];

        if (nestedData is List) {
          return nestedData;
        }
      }

      final jobs = decoded["jobs"];
      if (jobs is List) {
        return jobs;
      }

      final serviceJobs = decoded["service_jobs"];
      if (serviceJobs is List) {
        return serviceJobs;
      }

      final bookings = decoded["bookings"];
      if (bookings is List) {
        return bookings;
      }
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);
      final data = mapped["data"];

      if (data is List) {
        return data;
      }

      if (data is Map) {
        final nestedData = data["data"];

        if (nestedData is List) {
          return nestedData;
        }
      }
    }

    return [];
  }

  String _errorFromResponse(http.Response response, String fallback) {
    final decoded = _safeJsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      final message = decoded["message"]?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errors = decoded["errors"];

      if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;

        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }

        return firstValue.toString();
      }
    }

    return "$fallback. Status: ${response.statusCode}";
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final response = await http.get(
        Uri.parse("$baseUrl/technician/service-jobs?status=active"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MECHANIC JOB STATUS: ${response.statusCode}");
      debugPrint("MECHANIC JOB BODY: ${response.body}");

      if (response.statusCode == 200) {
        final jobs = _parseJobList(response.body);

        if (!mounted) return;

        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      } else {
        throw Exception(
          _errorFromResponse(
            response,
            "Gagal mengambil job teknisi",
          ),
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
    return _asMap(job["damage_report"]);
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> job) {
    final directVehicle = _asMap(job["vehicle"]);
    if (directVehicle != null) {
      return directVehicle;
    }

    final report = _getDamageReport(job);
    return _asMap(report?["vehicle"]);
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> job) {
    final directDriver = _asMap(job["driver"]);
    if (directDriver != null) {
      return directDriver;
    }

    final report = _getDamageReport(job);
    return _asMap(report?["driver"]);
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

  String _getDriverName(Map<String, dynamic> job) {
    final driver = _getDriver(job);

    if (driver == null) {
      return "Unknown Driver";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "Unknown Driver";
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

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final date = DateTime.parse(raw).toLocal();

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
      case "scheduled":
        return "Ready to Start";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
        return "In Progress";

      case "completed":
        return "Completed";

      case "canceled":
      case "cancelled":
        return "Canceled";

      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "scheduled":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in_progress":
        return Colors.amber;

      case "completed":
        return Colors.green;

      case "canceled":
      case "cancelled":
        return Colors.redAccent;

      default:
        return Colors.white54;
    }
  }

  bool _isDone(String status) {
    final lower = status.toLowerCase();

    return lower == "completed" ||
        lower == "canceled" ||
        lower == "cancelled";
  }


  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "scheduled":
        return Icons.play_circle_outline_rounded;

      case "rescheduled":
        return Icons.update_rounded;

      case "in_progress":
        return Icons.autorenew_rounded;

      case "completed":
        return Icons.check_circle_rounded;

      case "canceled":
      case "cancelled":
        return Icons.cancel_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  bool _matchesFilter(Map<String, dynamic> job) {
    if (_selectedFilter == "all") return true;

    final status = job["status"]?.toString().toLowerCase() ?? "";

    if (_selectedFilter == "ready") {
      return status == "approved" ||
          status == "scheduled" ||
          status == "rescheduled";
    }

    if (_selectedFilter == "in_progress") {
      return status == "in_progress";
    }

    if (_selectedFilter == "completed") {
      return status == "completed";
    }

    if (_selectedFilter == "canceled") {
      return status == "canceled" || status == "cancelled";
    }

    return true;
  }

  List<Map<String, dynamic>> get _mappedJobs {
    return _jobs
        .map((item) => _asMap(item))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final keyword = _searchQuery.trim().toLowerCase();

    return _mappedJobs.where((job) {
      final unit = _getUnitName(job).toLowerCase();
      final plate = _getPlateNumber(job).toLowerCase();
      final driver = _getDriverName(job).toLowerCase();
      final damageType = _getDamageType(job).toLowerCase();
      final status = _getStatusLabel(
        job["status"]?.toString() ?? "approved",
      ).toLowerCase();

      final matchSearch = keyword.isEmpty ||
          unit.contains(keyword) ||
          plate.contains(keyword) ||
          driver.contains(keyword) ||
          damageType.contains(keyword) ||
          status.contains(keyword);

      return matchSearch && _matchesFilter(job);
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
      case "ready":
        return "Ready";
      case "in_progress":
        return "Progress";
      case "completed":
        return "Done";
      case "canceled":
        return "Canceled";
      default:
        return value;
    }
  }

  Widget _buildHeaderDashboard() {
    final total = _mappedJobs.length;
    final ready = _countStatus(["approved", "scheduled", "rescheduled"]);
    final progress = _countStatus(["in_progress"]);
    final completed = _countStatus(["completed"]);

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
                icon: Icons.engineering_outlined,
                color: const Color(0xFFF9A825),
                size: 54,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Technician Jobs",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Kelola pekerjaan maintenance, mulai job, complete job, dan request sparepart.",
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
                  title: "Ready",
                  value: "$ready",
                  icon: Icons.play_circle_outline_rounded,
                  color: Colors.lightBlueAccent,
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
                  title: "Done",
                  value: "$completed",
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
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
          Icon(
            icon,
            color: color,
            size: 18,
          ),
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

  Widget _buildJobCard(Map<String, dynamic> job) {
    final bookingId = job["id"]?.toString() ?? "-";
    final reportId = job["damage_report_id"]?.toString() ??
        _getDamageReport(job)?["id"]?.toString() ??
        "-";

    final unit = _getUnitName(job);
    final plate = _getPlateNumber(job);
    final driver = _getDriverName(job);
    final damageType = _getDamageType(job);

    final status = job["status"]?.toString() ?? "approved";
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status);
    final isDone = _isDone(status);

    final scheduledAt = _formatDateTime(job["scheduled_at"]);
    final estimatedFinishAt = _formatDateTime(job["estimated_finish_at"]);

    return Opacity(
      opacity: isDone ? 0.62 : 1.0,
      child: Container(
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
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailsPage(
                  job: job,
                ),
              ),
            );

            if (!mounted) return;

            if (result == true) {
              await _loadTasks();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _iconBadge(
                      icon: _getStatusIcon(status),
                      color: statusColor,
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
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "#BK-$bookingId • #DR-$reportId",
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _statusChip(statusLabel, statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.confirmation_number_outlined,
                        label: "Plate",
                        value: plate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.person_outline_rounded,
                        label: "Driver",
                        value: driver,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.build_circle_outlined,
                        label: "Damage",
                        value: damageType,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.event_available_outlined,
                        label: "Schedule",
                        value: scheduledAt == "-"
                            ? "Belum tersedia"
                            : scheduledAt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _miniInfo(
                  icon: Icons.timer_outlined,
                  label: "Estimated Finish",
                  value: estimatedFinishAt == "-" ? "-" : estimatedFinishAt,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo({
    required IconData icon,
    required String label,
    required String value,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.052),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFF9A825),
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? "-" : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
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

  Widget _buildNoDataFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
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
            "Job tidak ditemukan",
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
                  "Gagal memuat job teknisi",
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
                    onPressed: _loadTasks,
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
        onRefresh: _loadTasks,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1A1D24),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            _iconBadge(
              icon: Icons.assignment_outlined,
              color: const Color(0xFFF9A825),
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              "Belum ada job maintenance",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Job akan muncul setelah admin approve dan menjadwalkan teknisi.",
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
      onRefresh: _loadTasks,
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
          const SizedBox(height: 18),
          if (jobs.isEmpty)
            _buildNoDataFound()
          else
            ...jobs.map((job) => _buildJobCard(job)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text(
          "Technician Jobs",
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
            onPressed: _loadTasks,
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

// -------------------------------------------------------------------
// SCREEN 2: DETAILS SERVICE JOB TEKNISI
// -------------------------------------------------------------------
class TaskDetailsPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const TaskDetailsPage({
    super.key,
    required this.job,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  Map<String, dynamic> get job => widget.job;

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic>? _getDamageReport() {
    return _asMap(job["damage_report"]);
  }

  Map<String, dynamic>? _getVehicle() {
    final directVehicle = _asMap(job["vehicle"]);
    if (directVehicle != null) {
      return directVehicle;
    }

    final report = _getDamageReport();
    return _asMap(report?["vehicle"]);
  }

  Map<String, dynamic>? _getDriver() {
    final directDriver = _asMap(job["driver"]);
    if (directDriver != null) {
      return directDriver;
    }

    final report = _getDamageReport();
    return _asMap(report?["driver"]);
  }

  int? _getDamageReportId() {
    final report = _getDamageReport();

    final rawId =
        job["damage_report_id"] ??
        job["damageReportId"] ??
        report?["id"];

    return int.tryParse(rawId?.toString() ?? "");
  }

  String _getUnitName() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    return "Unknown Unit";
  }

  String _getPlateNumber() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDamageType() {
    final report = _getDamageReport();

    return report?["damage_type"]?.toString() ??
        job["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription() {
    final report = _getDamageReport();

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

  String? _getDamageImageUrl() {
    final report = _getDamageReport();

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

  String _getDriverName() {
    final driver = _getDriver();

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

  String _getInitialHourMeterLabel() {
    final vehicle = _getVehicle();
    final report = _getDamageReport();

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

  String _getCurrentHourMeterLabel() {
    final vehicle = _getVehicle();
    final report = _getDamageReport();

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

  String _getCurrentMaLabel() {
    final vehicle = _getVehicle();

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

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final date = DateTime.parse(raw).toLocal();

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

  String _getStatus() {
    final status = job["status"]?.toString() ?? "approved";

    switch (status.toLowerCase()) {
      case "approved":
      case "scheduled":
        return "Ready to Start";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
        return "In Progress";

      case "completed":
        return "Completed";

      case "canceled":
      case "cancelled":
        return "Canceled";

      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "ready to start":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in progress":
        return Colors.amber;

      case "completed":
        return Colors.green;

      case "canceled":
      case "cancelled":
        return Colors.redAccent;

      default:
        return Colors.white54;
    }
  }

  bool _canStart() {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "approved" ||
        status == "scheduled" ||
        status == "rescheduled";
  }

  bool _canComplete() {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "in_progress";
  }

  bool _isClosed() {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" ||
        status == "finished" ||
        status == "selesai" ||
        status == "canceled" ||
        status == "cancelled" ||
        status == "dibatalkan";
  }

  bool _canRequestSparepart() {
    final damageReportId = _getDamageReportId();
    final status = job["status"]?.toString().toLowerCase() ?? "";

    // Sparepart hanya boleh diminta setelah teknisi benar-benar mulai job.
    return status == "in_progress" &&
        damageReportId != null &&
        damageReportId > 0;
  }

  String _getActionText() {
    if (_canStart()) {
      return "START JOB";
    }

    if (_canComplete()) {
      return "COMPLETE JOB";
    }

    if (_isClosed()) {
      return "TASK CLOSED";
    }

    return "NO ACTION AVAILABLE";
  }

  Future<void> _goToActionPage() async {
    if (_isClosed()) {
      return;
    }

    if (!_canStart() && !_canComplete()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Status job belum bisa diproses."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TaskUpdatePage(
          job: job,
          action: _canStart()
              ? TechnicianJobAction.start
              : TechnicianJobAction.complete,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openPartRequestModal() async {
    final damageReportId = _getDamageReportId();

    if (damageReportId == null || damageReportId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Damage report ID tidak valid."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RequestPartUsageModal(
          damageReportId: damageReportId,
          unitName: _getUnitName(),
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request sparepart berhasil dikirim ke admin."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }


  Widget _detailHero({
    required String unit,
    required String plate,
    required String bookingId,
    required String reportId,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.22),
            const Color(0xFF1A1D24),
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: statusColor.withOpacity(0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _detailIconBadge(
            icon: Icons.engineering_outlined,
            color: statusColor,
            size: 54,
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
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Plate: $plate • #BK-$bookingId • #DR-$reportId",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                _detailStatusChip(status, statusColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20242D).withOpacity(0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailSectionTitle(title, icon),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _detailSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFF9A825),
          size: 18,
        ),
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
    );
  }

  Widget _detailInfoGrid(List<_DetailInfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _detailInfoTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _detailInfoTile(_DetailInfoItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.052),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            color: item.color,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            item.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value.isEmpty ? "-" : item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTextBlock({
    required String title,
    required String value,
    required IconData icon,
    Color color = Colors.white70,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value.isEmpty ? "-" : value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSparepartPanel(bool canRequestSparepart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailTextBlock(
          title: "Sparepart Request",
          value: canRequestSparepart
              ? "Cari dan request sparepart yang dibutuhkan selama pekerjaan sedang berlangsung."
              : "Request sparepart hanya tersedia setelah job dimulai oleh teknisi.",
          icon: Icons.inventory_2_outlined,
          color: canRequestSparepart
              ? const Color(0xFFF9A825)
              : Colors.white54,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: canRequestSparepart ? _openPartRequestModal : null,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text(
              "REQUEST SPAREPART",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF9A825),
              disabledForegroundColor: Colors.white24,
              side: BorderSide(
                color: canRequestSparepart
                    ? const Color(0xFFF9A825)
                    : Colors.white12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (!canRequestSparepart) ...[
          const SizedBox(height: 10),
          const Text(
            "Klik START JOB terlebih dahulu. Setelah status menjadi In Progress, teknisi baru bisa request sparepart.",
            style: TextStyle(
              color: Colors.white30,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailBottomActionBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1115),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isClosed() ? Colors.white12 : const Color(0xFFF9A825),
              disabledBackgroundColor: Colors.white12,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isClosed() ? null : _goToActionPage,
            icon: Icon(
              _canStart()
                  ? Icons.play_arrow_rounded
                  : _canComplete()
                      ? Icons.check_circle_outline_rounded
                      : Icons.lock_outline_rounded,
              color: _isClosed() ? Colors.white38 : Colors.black,
            ),
            label: Text(
              _getActionText(),
              style: TextStyle(
                color: _isClosed() ? Colors.white38 : Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
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

  Widget _detailIconBadge({
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


  @override
  Widget build(BuildContext context) {
    final unit = _getUnitName();
    final plate = _getPlateNumber();
    final status = _getStatus();
    final statusColor = _getStatusColor(status);

    final bookingId = job["id"]?.toString() ?? "-";
    final reportId =
        job["damage_report_id"]?.toString() ??
        _getDamageReport()?["id"]?.toString() ??
        "-";

    final canRequestSparepart = _canRequestSparepart();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text(
          "Task Details",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
      ),
      bottomNavigationBar: _detailBottomActionBar(),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailHero(
                unit: unit,
                plate: plate,
                bookingId: bookingId,
                reportId: reportId,
                status: status,
                statusColor: statusColor,
              ),
              _detailSectionCard(
                title: "Report Details",
                icon: Icons.report_problem_outlined,
                child: Column(
                  children: [
                    _detailInfoGrid([
                      _DetailInfoItem(
                        title: "Driver",
                        value: _getDriverName(),
                        icon: Icons.person_outline_rounded,
                        color: Colors.greenAccent,
                      ),
                      _DetailInfoItem(
                        title: "Damage Type",
                        value: _getDamageType(),
                        icon: Icons.build_circle_outlined,
                        color: Colors.orangeAccent,
                      ),
                      _DetailInfoItem(
                        title: "Reported At",
                        value: _formatDate(_getDamageReport()?["created_at"]),
                        icon: Icons.event_note_outlined,
                        color: Colors.white70,
                      ),
                      _DetailInfoItem(
                        title: "Scheduled At",
                        value: _formatDate(job["scheduled_at"]),
                        icon: Icons.event_available_outlined,
                        color: const Color(0xFFF9A825),
                      ),
                      _DetailInfoItem(
                        title: "Est. Finish",
                        value: _formatDate(job["estimated_finish_at"]),
                        icon: Icons.timer_outlined,
                        color: Colors.lightBlueAccent,
                      ),
                      _DetailInfoItem(
                        title: "Priority",
                        value: job["priority"]?.toString() ?? "-",
                        icon: Icons.flag_outlined,
                        color: Colors.purpleAccent,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _detailTextBlock(
                      title: "Description",
                      value: _getDescription(),
                      icon: Icons.description_outlined,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 14),
                    _buildDamageImageSection(),
                  ],
                ),
              ),
              _detailSectionCard(
                title: "Unit Performance",
                icon: Icons.analytics_outlined,
                child: _detailInfoGrid([
                  _DetailInfoItem(
                    title: "Initial HM",
                    value: _getInitialHourMeterLabel(),
                    icon: Icons.speed_outlined,
                    color: const Color(0xFFF9A825),
                  ),
                  _DetailInfoItem(
                    title: "Current HM",
                    value: _getCurrentHourMeterLabel(),
                    icon: Icons.av_timer_outlined,
                    color: Colors.orangeAccent,
                  ),
                  _DetailInfoItem(
                    title: "Latest MA",
                    value: _getCurrentMaLabel(),
                    icon: Icons.verified_outlined,
                    color: Colors.greenAccent,
                  ),
                  _DetailInfoItem(
                    title: "Started At",
                    value: _formatDate(job["started_at"]),
                    icon: Icons.play_circle_outline_rounded,
                    color: Colors.lightBlueAccent,
                  ),
                  _DetailInfoItem(
                    title: "Completed At",
                    value: _formatDate(job["completed_at"]),
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.greenAccent,
                  ),
                ]),
              ),
              _detailSectionCard(
                title: "Notes",
                icon: Icons.notes_outlined,
                child: Column(
                  children: [
                    _detailTextBlock(
                      title: "Driver Note",
                      value: job["note_driver"]?.toString() ?? "-",
                      icon: Icons.drive_eta_outlined,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 10),
                    _detailTextBlock(
                      title: "Admin Note",
                      value: job["note_admin"]?.toString() ?? "-",
                      icon: Icons.admin_panel_settings_outlined,
                      color: const Color(0xFFF9A825),
                    ),
                    const SizedBox(height: 10),
                    _detailTextBlock(
                      title: "Technician Note",
                      value: job["note_technician"]?.toString() ?? "-",
                      icon: Icons.engineering_outlined,
                      color: Colors.lightBlueAccent,
                    ),
                  ],
                ),
              ),
              _detailSectionCard(
                title: "Technician Tools",
                icon: Icons.handyman_outlined,
                child: _detailSparepartPanel(canRequestSparepart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoBox({
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDamageImageSection() {
    final imageUrl = _getDamageImageUrl();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Damage Photo",
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        if (imageUrl == null)
          Container(
            width: double.infinity,
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity( 0.08),
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
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return Container(
                        width: double.infinity,
                        height: 190,
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
                        height: 150,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity( 0.08),
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

  Widget _noteBox(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity( 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DetailInfoItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailInfoItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

// -------------------------------------------------------------------
// SCREEN 3: START / COMPLETE SERVICE JOB
// -------------------------------------------------------------------
enum TechnicianJobAction {
  start,
  complete,
}

class TaskUpdatePage extends StatefulWidget {
  final Map<String, dynamic> job;
  final TechnicianJobAction action;

  const TaskUpdatePage({
    super.key,
    required this.job,
    required this.action,
  });

  @override
  State<TaskUpdatePage> createState() => _TaskUpdatePageState();
}

class _TaskUpdatePageState extends State<TaskUpdatePage> {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";

  final TextEditingController _noteController = TextEditingController();

  /*
  |--------------------------------------------------------------------------
  | INPUT DATA PENYELESAIAN MAINTENANCE
  |--------------------------------------------------------------------------
  |
  | Penting:
  | - initial_hour_meter tetap data awal dari admin.
  | - Teknisi tidak mengubah initial.
  | - Teknisi hanya mengirim final/current hour meter dan data mentah.
  | - Backend yang menghitung nilai resmi MTTR, MTBF, dan MA.
  |
  */
  final TextEditingController _finalHourMeter = TextEditingController();
  final TextEditingController _repairTime = TextEditingController();
  final TextEditingController _failures = TextEditingController(text: "1");
  final TextEditingController _opTime = TextEditingController();
  final TextEditingController _actualOp = TextEditingController();
  final TextEditingController _breakdown = TextEditingController();

  bool _isSubmitting = false;

  bool get _isStartAction => widget.action == TechnicianJobAction.start;

  bool get _isCompleteAction => widget.action == TechnicianJobAction.complete;

  @override
  void initState() {
    super.initState();
    _prefillCurrentVehicleValue();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _finalHourMeter.dispose();
    _repairTime.dispose();
    _failures.dispose();
    _opTime.dispose();
    _actualOp.dispose();
    _breakdown.dispose();
    super.dispose();
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

  String _errorFromResponse(http.Response response, String fallback) {
    final decoded = _safeJsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      final message = decoded["message"]?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errors = decoded["errors"];

      if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;

        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }

        return firstValue.toString();
      }
    }

    return "$fallback. Status: ${response.statusCode}";
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

  Map<String, dynamic>? _getDamageReport() {
    return _asMap(widget.job["damage_report"]) ??
        _asMap(widget.job["damageReport"]) ??
        _asMap(widget.job["report"]);
  }

  Map<String, dynamic>? _getVehicle() {
    final directVehicle = _asMap(widget.job["vehicle"]);
    if (directVehicle != null) {
      return directVehicle;
    }

    final report = _getDamageReport();
    return _asMap(report?["vehicle"]);
  }

  String _unitName() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    return "Unknown Unit";
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

  dynamic _currentHourMeterValue() {
    final vehicle = _getVehicle();
    final report = _getDamageReport();

    return _firstAvailableValue([
      widget.job["final_hour_meter"],
      widget.job["current_hour_meter"],
      widget.job["latest_hour_meter"],
      vehicle?["current_hour_meter"],
      vehicle?["latest_hour_meter"],
      vehicle?["final_hour_meter"],
      report?["vehicle_current_hour_meter"],
      vehicle?["initial_hour_meter"],
      vehicle?["initial_kpi"],
      widget.job["initial_hour_meter"],
      widget.job["initial_kpi"],
    ]);
  }

  dynamic _initialHourMeterValue() {
    final vehicle = _getVehicle();
    final report = _getDamageReport();

    return _firstAvailableValue([
      vehicle?["initial_hour_meter"],
      vehicle?["initial_kpi"],
      report?["vehicle_initial_hour_meter"],
      report?["vehicle_initial_kpi"],
      widget.job["initial_hour_meter"],
      widget.job["initial_kpi"],
    ]);
  }

  void _prefillCurrentVehicleValue() {
    final currentValue = _currentHourMeterValue();

    if (currentValue != null) {
      _finalHourMeter.text = _formatNumber(currentValue);
    }
  }

  double _parseNumber(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(",", ".");
    return double.tryParse(value) ?? 0;
  }

  bool _isEmptyNumber(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty || value == "null";
  }

  void _validateCompleteInput() {
    if (!_isCompleteAction) return;

    if (_isEmptyNumber(_finalHourMeter)) {
      throw Exception(
        "Hour meter terbaru wajib diisi agar admin dan driver melihat kondisi terbaru unit.",
      );
    }

    if (_isEmptyNumber(_repairTime)) {
      throw Exception("Total repair time wajib diisi.");
    }

    if (_isEmptyNumber(_opTime)) {
      throw Exception("Total operational time wajib diisi.");
    }

    if (_isEmptyNumber(_failures)) {
      throw Exception("Number of failures wajib diisi.");
    }

    if (_isEmptyNumber(_actualOp)) {
      throw Exception("Actual operating hours wajib diisi.");
    }

    if (_isEmptyNumber(_breakdown)) {
      throw Exception("Breakdown hours wajib diisi.");
    }

    final failures = _parseNumber(_failures);
    final actualOperatingHours = _parseNumber(_actualOp);
    final breakdownHours = _parseNumber(_breakdown);

    if (failures <= 0) {
      throw Exception("Number of failures minimal 1.");
    }

    if (actualOperatingHours + breakdownHours <= 0) {
      throw Exception(
        "Actual operating hours dan breakdown hours tidak boleh sama-sama 0.",
      );
    }
  }

  void _putIfFilled(
    Map<String, String> body,
    String key,
    TextEditingController controller,
  ) {
    final value = controller.text.trim().replaceAll(",", ".");

    if (value.isNotEmpty) {
      body[key] = value;
    }
  }

  Future<void> _submitJobAction() async {
    if (_isSubmitting) return;

    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final bookingId = widget.job["id"]?.toString();

      if (bookingId == null || bookingId.isEmpty || bookingId == "null") {
        throw Exception("Booking ID tidak valid.");
      }

      _validateCompleteInput();

      final endpoint = _isStartAction
          ? "$baseUrl/technician/service-jobs/$bookingId/start"
          : "$baseUrl/technician/service-jobs/$bookingId/complete";

      final body = <String, String>{};

      if (_noteController.text.trim().isNotEmpty) {
        body["note_technician"] = _noteController.text.trim();
      }

      if (_isCompleteAction) {
        /*
        |------------------------------------------------------------------
        | FIELD UNTUK BACKEND
        |------------------------------------------------------------------
        |
        | Backend sebaiknya memakai field ini untuk:
        | - update vehicles.current_hour_meter / latest_hour_meter
        | - hitung MTTR, MTBF, dan MA
        | - simpan hasil ke service_bookings / repair history
        |
        | Alias dikirim agar kompatibel dengan beberapa penamaan controller.
        |
        */
        _putIfFilled(body, "final_hour_meter", _finalHourMeter);
        _putIfFilled(body, "current_hour_meter", _finalHourMeter);
        _putIfFilled(body, "latest_hour_meter", _finalHourMeter);

        _putIfFilled(body, "total_repair_time", _repairTime);
        _putIfFilled(body, "repair_time", _repairTime);
        _putIfFilled(body, "repair_time_hours", _repairTime);

        _putIfFilled(body, "total_operational_time", _opTime);
        _putIfFilled(body, "operational_time", _opTime);
        _putIfFilled(body, "operational_time_hours", _opTime);

        _putIfFilled(body, "failure_count", _failures);
        _putIfFilled(body, "number_of_failures", _failures);
        _putIfFilled(body, "failures", _failures);

        _putIfFilled(body, "actual_operating_hours", _actualOp);
        _putIfFilled(body, "actual_operation_hours", _actualOp);

        _putIfFilled(body, "breakdown_hours", _breakdown);
        _putIfFilled(body, "breakdown_time", _breakdown);
      }

      debugPrint("JOB ACTION URL: $endpoint");
      debugPrint("JOB ACTION BODY: $body");

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body,
      );

      debugPrint("JOB ACTION STATUS: ${response.statusCode}");
      debugPrint("JOB ACTION BODY: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isStartAction
                  ? "Job berhasil dimulai."
                  : "Job berhasil diselesaikan. Data terbaru dikirim ke backend.",
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception(
          _errorFromResponse(
            response,
            "Gagal update job",
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst("Exception: ", ""),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  Widget _updateHero({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.22),
            const Color(0xFF1A1D24),
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: color.withOpacity(0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _updateIconBadge(
            icon: _isStartAction
                ? Icons.play_circle_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _unitName(),
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    );
  }

  Widget _updateSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF20242D).withOpacity(0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFF9A825),
                size: 18,
              ),
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

  Widget _updateMessage({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _updateIconBadge({
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

  Widget _updateBottomBar() {
    final color = _isStartAction
        ? Colors.lightBlueAccent
        : const Color(0xFFF9A825);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1115),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: Colors.white12,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isSubmitting ? null : _submitJobAction,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _isStartAction
                        ? Icons.play_arrow_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.black,
                  ),
            label: Text(
              _isSubmitting
                  ? "MEMPROSES..."
                  : _isStartAction
                      ? "START SERVICE"
                      : "COMPLETE SERVICE",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final title = _isStartAction ? "Start Job" : "Complete Job";
    final color = _isStartAction
        ? Colors.lightBlueAccent
        : const Color(0xFFF9A825);

    final subtitle = _isStartAction
        ? "Teknisi akan memulai pekerjaan. Driver akan menerima notifikasi servis dimulai."
        : "Teknisi menyelesaikan pekerjaan. Data mentah dikirim ke backend untuk menghitung MA, MTTR, MTBF, dan memperbarui kondisi terbaru kendaraan.";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF0F1115),
        elevation: 0,
      ),
      bottomNavigationBar: _updateBottomBar(),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _updateHero(
                title: title,
                subtitle: subtitle,
                color: color,
              ),
              _updateSectionCard(
                title: _isStartAction
                    ? "Catatan Awal Teknisi"
                    : "Catatan Penyelesaian Teknisi",
                icon: Icons.notes_outlined,
                child: TextField(
                  controller: _noteController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: const Color(0xFFF9A825),
                  decoration: InputDecoration(
                    hintText: _isStartAction
                        ? "Contoh: Mulai pengecekan unit..."
                        : "Contoh: Oli sudah diganti, unit normal kembali...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.055),
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
                ),
              ),
              if (_isCompleteAction) ...[
                _updateSectionCard(
                  title: "Update Kondisi Unit",
                  icon: Icons.speed_outlined,
                  child: Column(
                    children: [
                      _updateMessage(
                        icon: Icons.info_outline_rounded,
                        color: Colors.lightBlueAccent,
                        message:
                            "Initial hour meter tetap menjadi data awal dari admin. Teknisi hanya mengisi hour meter terbaru setelah perbaikan.",
                      ),
                      const SizedBox(height: 12),
                      _readOnlyInfoRow(
                        "Initial Hour Meter",
                        _formatNumber(_initialHourMeterValue()),
                      ),
                      _readOnlyInfoRow(
                        "Current/Last Hour Meter",
                        _formatNumber(_currentHourMeterValue()),
                      ),
                      const SizedBox(height: 12),
                      _input(
                        "Hour Meter Terbaru Setelah Perbaikan",
                        _finalHourMeter,
                        hint: "Contoh: 185",
                      ),
                    ],
                  ),
                ),
                _updateSectionCard(
                  title: "Data Mentah Maintenance",
                  icon: Icons.analytics_outlined,
                  child: Column(
                    children: [
                      _updateMessage(
                        icon: Icons.calculate_outlined,
                        color: const Color(0xFFF9A825),
                        message:
                            "Isi angka mentahnya saja. Nilai resmi MTTR, MTBF, dan MA dihitung di backend, bukan di Flutter.",
                      ),
                      const SizedBox(height: 12),
                      _input(
                        "Total Repair Time (Jam)",
                        _repairTime,
                        hint: "Contoh: 4",
                      ),
                      _input(
                        "Total Operational Time (Jam)",
                        _opTime,
                        hint: "Contoh: 120",
                      ),
                      _input(
                        "Number of Failures",
                        _failures,
                        hint: "Contoh: 1",
                      ),
                      _input(
                        "Actual Operating Hours",
                        _actualOp,
                        hint: "Contoh: 116",
                      ),
                      _input(
                        "Breakdown Hours",
                        _breakdown,
                        hint: "Contoh: 4",
                      ),
                      const SizedBox(height: 4),
                      _updateMessage(
                        icon: Icons.storage_outlined,
                        color: Colors.white54,
                        message:
                            "Setelah COMPLETE SERVICE ditekan, backend perlu menyimpan data ini ke service booking/repair history dan update current_hour_meter serta current_ma pada kendaraan.",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Fitur cetak laporan bisa disambungkan nanti.",
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text(
                      "CETAK LAPORAN",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }


  Widget _input(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: const Color(0xFFF9A825),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white.withOpacity(0.055),
          labelStyle: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: const TextStyle(
            color: Colors.white30,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: const Color(0xFFF9A825).withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyInfoRow(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF9A825),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// MODAL: REQUEST SPAREPART TEKNISI
// -------------------------------------------------------------------
class RequestPartUsageModal extends StatefulWidget {
  final int damageReportId;
  final String unitName;

  const RequestPartUsageModal({
    super.key,
    required this.damageReportId,
    required this.unitName,
  });

  @override
  State<RequestPartUsageModal> createState() => _RequestPartUsageModalState();
}

class _RequestPartUsageModalState extends State<RequestPartUsageModal> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _noteController = TextEditingController();

  Timer? _searchDebounce;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<dynamic> _parts = [];
  int? _selectedPartId;

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
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

  Map<String, dynamic>? _selectedPart() {
    if (_selectedPartId == null) {
      return null;
    }

    for (final item in _parts) {
      final part = _asMap(item);
      if (part == null) continue;

      final id = int.tryParse(part["id"]?.toString() ?? "") ?? 0;

      if (id == _selectedPartId) {
        return part;
      }
    }

    return null;
  }

  Future<void> _loadParts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final parts = await TechnicianPartUsageService.getParts(
        search: _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _parts = parts;

        final selectedStillExists = _selectedPartId != null &&
            _parts
                .map((item) => _asMap(item))
                .whereType<Map<String, dynamic>>()
                .any((part) {
              final id =
                  int.tryParse(part["id"]?.toString() ?? "") ?? 0;
              return id == _selectedPartId;
            });

        if (!selectedStillExists) {
          _selectedPartId = null;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _parts = [];
        _selectedPartId = null;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        _loadParts();
      },
    );
  }

  int _getStock(Map<String, dynamic>? part) {
    if (part == null) return 0;

    return int.tryParse(part["stock"]?.toString() ?? "0") ?? 0;
  }

  String _getPartName(Map<String, dynamic>? part) {
    if (part == null) return "-";

    return part["name"]?.toString() ?? "-";
  }

  String _getPartSku(Map<String, dynamic>? part) {
    if (part == null) return "-";

    return part["sku"]?.toString() ?? "-";
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    final partId = _selectedPartId;
    final selectedPart = _selectedPart();
    final stock = _getStock(selectedPart);
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;

    if (partId == null || partId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih sparepart terlebih dahulu."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (qty < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Qty minimal 1."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Stok sparepart ini sedang kosong."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (qty > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Qty melebihi stok tersedia. Stok saat ini: $stock."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await TechnicianPartUsageService.requestPartUsage(
        partId: partId,
        damageReportId: widget.damageReportId,
        qty: qty,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        labelText: "Search sparepart",
        hintText: "Cari nama part atau SKU...",
        labelStyle: const TextStyle(color: Colors.white38),
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: const Icon(
          Icons.search,
          color: Colors.white38,
        ),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  _loadParts();
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white38,
                ),
              ),
        filled: true,
        fillColor: Colors.white10,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPartPicker() {
    if (_isLoading) {
      return const SizedBox(
        height: 170,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF9A825),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity( 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.redAccent.withOpacity( 0.25),
          ),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      );
    }

    final mappedParts = _parts
        .map((item) => _asMap(item))
        .whereType<Map<String, dynamic>>()
        .toList();

    if (mappedParts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity( 0.035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity( 0.05),
          ),
        ),
        child: const Text(
          "Sparepart tidak ditemukan. Coba kata kunci lain.",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 260,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: mappedParts.length,
        itemBuilder: (context, index) {
          final part = mappedParts[index];

          final id = int.tryParse(part["id"]?.toString() ?? "") ?? 0;
          final sku = _getPartSku(part);
          final name = _getPartName(part);
          final stock = _getStock(part);
          final isSelected = _selectedPartId == id;
          final isEmptyStock = stock <= 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFF9A825).withOpacity( 0.12)
                  : Colors.white.withOpacity( 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF9A825)
                    : Colors.white12,
              ),
            ),
            child: ListTile(
              enabled: !isEmptyStock,
              onTap: isEmptyStock
                  ? null
                  : () {
                      setState(() {
                        _selectedPartId = id;
                      });
                    },
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isEmptyStock ? Colors.white30 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "SKU: $sku • Stok: $stock",
                  style: TextStyle(
                    color: isEmptyStock ? Colors.redAccent : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
              trailing: isEmptyStock
                  ? const Text(
                      "Kosong",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFFF9A825),
                        )
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.white24,
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPartInfo() {
    final selectedPart = _selectedPart();

    if (selectedPart == null) {
      return const SizedBox.shrink();
    }

    final name = _getPartName(selectedPart);
    final sku = _getPartSku(selectedPart);
    final stock = _getStock(selectedPart);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9A825).withOpacity( 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF9A825).withOpacity( 0.18),
        ),
      ),
      child: Text(
        "Dipilih: $sku — $name • Stok tersedia: $stock",
        style: const TextStyle(
          color: Color(0xFFF9A825),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Request Sparepart",
                style: TextStyle(
                  color: Color(0xFFF9A825),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.unitName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Search aktif otomatis saat diketik. Pilih part dari list, lalu masukkan qty yang dibutuhkan.",
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _buildSearchField(),
              const SizedBox(height: 12),
              _buildPartPicker(),
              _buildSelectedPartInfo(),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Qty",
                  labelStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Catatan",
                  hintText: "Contoh: Butuh untuk penggantian filter...",
                  labelStyle: TextStyle(color: Colors.white38),
                  hintStyle: TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9A825),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.black,
                        )
                      : const Text(
                          "KIRIM REQUEST",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
