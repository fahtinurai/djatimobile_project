import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';

// -------------------------------------------------------------------
// 1. HALAMAN DAFTAR MONITORING UNIT OPERATOR / DRIVER
// -------------------------------------------------------------------
class AnalyticsReportPage extends StatefulWidget {
  const AnalyticsReportPage({super.key});

  @override
  State<AnalyticsReportPage> createState() => _AnalyticsReportPageState();
}

class _AnalyticsReportPageState extends State<AnalyticsReportPage> {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];

  String _searchQuery = "";
  String _selectedFilter = "all";

  final List<String> _filters = const [
    "all",
    "requested",
    "approved",
    "in_progress",
    "completed",
    "on_hold",
    "canceled",
    "rejected",
  ];

  @override
  void initState() {
    super.initState();
    _loadDamageReports();
  }

  // -------------------------------------------------------------------
  // API
  // -------------------------------------------------------------------

  Future<void> _loadDamageReports() async {
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
        Uri.parse("$baseUrl/driver/damage-reports"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("UNIT TRACKING STATUS: ${response.statusCode}");
      debugPrint("UNIT TRACKING BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> rawReports = [];

        if (decoded is List) {
          rawReports = decoded;
        } else if (decoded is Map<String, dynamic> && decoded["data"] is List) {
          rawReports = decoded["data"];
        }

        final safeReports = rawReports
            .map((item) => _asMap(item))
            .whereType<Map<String, dynamic>>()
            .toList();

        if (!mounted) return;

        setState(() {
          _reports = safeReports;
          _isLoading = false;
        });
      } else {
        throw Exception("Gagal mengambil unit tracking: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  // -------------------------------------------------------------------
  // DATA NORMALIZER
  // -------------------------------------------------------------------

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> item) {
    final nested = _asMap(item["damage_report"]);

    if (nested != null) {
      return nested;
    }

    final camelNested = _asMap(item["damageReport"]);

    if (camelNested != null) {
      return camelNested;
    }

    return item;
  }

  Map<String, dynamic>? _getBooking(Map<String, dynamic> item) {
    final serviceBooking = _asMap(item["service_booking"]);

    if (serviceBooking != null) {
      return serviceBooking;
    }

    final latestServiceBooking = _asMap(item["latest_service_booking"]);

    if (latestServiceBooking != null) {
      return latestServiceBooking;
    }

    final booking = _asMap(item["booking"]);

    if (booking != null) {
      return booking;
    }

    final hasBookingFields = item["scheduled_at"] != null ||
        item["preferred_at"] != null ||
        item["estimated_finish_at"] != null ||
        item["requested_at"] != null ||
        item["started_at"] != null ||
        item["completed_at"] != null ||
        item["damage_report"] != null;

    if (hasBookingFields) {
      return item;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final damageReport = _getDamageReport(item);

    final bookingVehicle = _asMap(booking?["vehicle"]);

    if (bookingVehicle != null) {
      return bookingVehicle;
    }

    final reportVehicle = _asMap(damageReport?["vehicle"]);

    if (reportVehicle != null) {
      return reportVehicle;
    }

    final directVehicle = _asMap(item["vehicle"]);

    if (directVehicle != null) {
      return directVehicle;
    }

    return null;
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final damageReport = _getDamageReport(item);

    final bookingDriver = _asMap(booking?["driver"]);

    if (bookingDriver != null) {
      return bookingDriver;
    }

    final reportDriver = _asMap(damageReport?["driver"]);

    if (reportDriver != null) {
      return reportDriver;
    }

    final directDriver = _asMap(item["driver"]);

    if (directDriver != null) {
      return directDriver;
    }

    return null;
  }

  Map<String, dynamic>? _getTechnician(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    final technician = _asMap(booking?["technician"]);

    if (technician != null) {
      return technician;
    }

    final mechanic = _asMap(booking?["mechanic"]);

    if (mechanic != null) {
      return mechanic;
    }

    final assignedTechnician = _asMap(booking?["assigned_technician"]);

    if (assignedTechnician != null) {
      return assignedTechnician;
    }

    final assignedTechnicianCamel = _asMap(booking?["assignedTechnician"]);

    if (assignedTechnicianCamel != null) {
      return assignedTechnicianCamel;
    }

    return null;
  }

  Map<String, dynamic>? _getLatestResponse(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    final latestFromReport = _asMap(damageReport?["latest_technician_response"]);

    if (latestFromReport != null) {
      return latestFromReport;
    }

    final latestFromReportCamel =
        _asMap(damageReport?["latestTechnicianResponse"]);

    if (latestFromReportCamel != null) {
      return latestFromReportCamel;
    }

    final latestDirect = _asMap(item["latest_technician_response"]);

    if (latestDirect != null) {
      return latestDirect;
    }

    final latestDirectCamel = _asMap(item["latestTechnicianResponse"]);

    if (latestDirectCamel != null) {
      return latestDirectCamel;
    }

    return null;
  }

  List<dynamic> _getTechnicianResponses(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    final fromReport = damageReport?["technician_responses"];

    if (fromReport is List) {
      return fromReport;
    }

    final direct = item["technician_responses"];

    if (direct is List) {
      return direct;
    }

    return [];
  }

  // -------------------------------------------------------------------
  // FORMATTER
  // -------------------------------------------------------------------

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final normalized =
          raw.contains(" ") && !raw.contains("T") ? raw.replaceFirst(" ", "T") : raw;

      final date = DateTime.parse(normalized).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, "0");
      final minute = date.minute.toString().padLeft(2, "0");

      return "$day-$month-$year $hour:$minute WIB";
    } catch (_) {
      return raw;
    }
  }

  // -------------------------------------------------------------------
  // GETTER DISPLAY
  // -------------------------------------------------------------------

  String _getUnitName(Map<String, dynamic> item) {
    final vehicle = _getVehicle(item);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    final damageReport = _getDamageReport(item);

    return damageReport?["equipment_name"]?.toString() ??
        item["equipment_name"]?.toString() ??
        "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> item) {
    final vehicle = _getVehicle(item);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDriverName(Map<String, dynamic> item) {
    final driver = _getDriver(item);

    if (driver == null) {
      return "-";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "-";
  }

  String _getTechnicianName(Map<String, dynamic> item) {
    final technician = _getTechnician(item);

    if (technician == null) {
      return "Belum ditugaskan";
    }

    return technician["name"]?.toString() ??
        technician["username"]?.toString() ??
        "Teknisi";
  }

  String _getDamageType(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    return damageReport?["damage_type"]?.toString() ??
        item["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    return damageReport?["description"]?.toString() ??
        damageReport?["note"]?.toString() ??
        item["description"]?.toString() ??
        "-";
  }

  String _getReportId(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    final id = damageReport?["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#DR-$id";
  }

  String _getBookingId(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    final id = booking?["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#BK-$id";
  }

  String _getRequestedAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final damageReport = _getDamageReport(item);

    return _formatDateTime(
      booking?["requested_at"] ??
          booking?["created_at"] ??
          damageReport?["created_at"] ??
          item["created_at"],
    );
  }

  String _getPreferredAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return _formatDateTime(booking?["preferred_at"]);
  }

  String _getScheduledAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return _formatDateTime(booking?["scheduled_at"]);
  }

  String _getEstimatedFinishAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return _formatDateTime(booking?["estimated_finish_at"]);
  }

  String _getStartedAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return _formatDateTime(booking?["started_at"]);
  }

  String _getCompletedAt(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return _formatDateTime(booking?["completed_at"]);
  }

  String _getNoteDriver(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return booking?["note_driver"]?.toString() ?? "-";
  }

  String _getNoteAdmin(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return booking?["note_admin"]?.toString() ?? "-";
  }

  String _getNoteTechnician(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final latest = _getLatestResponse(item);

    return booking?["note_technician"]?.toString() ??
        latest?["note"]?.toString() ??
        latest?["response_note"]?.toString() ??
        "-";
  }

  String _getPriority(Map<String, dynamic> item) {
    final booking = _getBooking(item);

    return booking?["priority"]?.toString() ?? "-";
  }

  // -------------------------------------------------------------------
  // STATUS
  // -------------------------------------------------------------------

  String _getRawStatus(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final damageReport = _getDamageReport(item);
    final latest = _getLatestResponse(item);

    return booking?["status"]?.toString() ??
        damageReport?["status"]?.toString() ??
        latest?["status"]?.toString() ??
        item["status"]?.toString() ??
        "reported";
  }

  String _getStatus(Map<String, dynamic> item) {
    final status = _getRawStatus(item).toLowerCase();

    switch (status) {
      case "requested":
      case "pending":
      case "menunggu":
      case "reported":
        return "Requested";

      case "approved":
      case "scheduled":
        return "Approved";

      case "rescheduled":
        return "Rescheduled";

      case "proses":
      case "diproses":
      case "ongoing":
      case "in_progress":
        return "In Progress";

      case "butuh_followup_admin":
      case "menunggu_sparepart":
      case "waiting_parts":
      case "waiting parts":
      case "on_hold":
      case "on hold":
        return "On Hold";

      case "selesai":
      case "finished":
      case "completed":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "rejected":
      case "ditolak":
        return "Rejected";

      case "fatal":
        return "Fatal";

      default:
        return _getRawStatus(item);
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case "requested":
        return "Laporan sudah dibuat dan booking maintenance sedang menunggu approval admin.";

      case "approved":
        return "Admin sudah menyetujui booking dan menentukan jadwal. Teknisi akan mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "on hold":
        return "Pekerjaan tertunda dan membutuhkan tindak lanjut admin atau sparepart.";

      case "completed":
        return "Maintenance kendaraan sudah selesai dikerjakan.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Laporan atau booking ditolak.";

      case "fatal":
        return "Unit ditandai mengalami kerusakan fatal.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "requested":
        return Colors.orangeAccent;

      case "approved":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in progress":
        return Colors.amberAccent;

      case "on hold":
        return Colors.redAccent;

      case "completed":
        return Colors.greenAccent;

      case "canceled":
        return Colors.grey;

      case "rejected":
        return Colors.redAccent;

      case "fatal":
        return Colors.red;

      default:
        return Colors.white54;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "requested":
        return Icons.hourglass_top_rounded;

      case "approved":
        return Icons.event_available_rounded;

      case "rescheduled":
        return Icons.update_rounded;

      case "in progress":
        return Icons.autorenew_rounded;

      case "on hold":
        return Icons.pause_circle_outline_rounded;

      case "completed":
        return Icons.check_circle_rounded;

      case "canceled":
        return Icons.cancel_rounded;

      case "rejected":
        return Icons.block_rounded;

      case "fatal":
        return Icons.report_gmailerrorred_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  String _mapStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "menunggu":
      case "reported":
        return "Requested";

      case "approved":
      case "scheduled":
        return "Approved";

      case "rescheduled":
        return "Rescheduled";

      case "proses":
      case "diproses":
      case "ongoing":
      case "in_progress":
        return "In Progress";

      case "butuh_followup_admin":
      case "menunggu_sparepart":
      case "waiting_parts":
      case "waiting parts":
      case "on_hold":
      case "on hold":
        return "On Hold";

      case "selesai":
      case "finished":
      case "completed":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "rejected":
      case "ditolak":
        return "Rejected";

      case "fatal":
        return "Fatal";

      default:
        return status;
    }
  }

  // -------------------------------------------------------------------
  // FILTER
  // -------------------------------------------------------------------

  bool _matchFilter(Map<String, dynamic> item) {
    if (_selectedFilter == "all") return true;

    final status = _getStatus(item).toLowerCase();

    if (_selectedFilter == "requested") {
      return status == "requested";
    }

    if (_selectedFilter == "approved") {
      return status == "approved" || status == "rescheduled";
    }

    if (_selectedFilter == "in_progress") {
      return status == "in progress";
    }

    if (_selectedFilter == "completed") {
      return status == "completed";
    }

    if (_selectedFilter == "on_hold") {
      return status == "on hold";
    }

    if (_selectedFilter == "canceled") {
      return status == "canceled";
    }

    if (_selectedFilter == "rejected") {
      return status == "rejected";
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredReports {
    final keyword = _searchQuery.trim().toLowerCase();

    return _reports.where((item) {
      final unit = _getUnitName(item).toLowerCase();
      final plate = _getPlateNumber(item).toLowerCase();
      final technician = _getTechnicianName(item).toLowerCase();
      final status = _getStatus(item).toLowerCase();

      final matchSearch = keyword.isEmpty ||
          unit.contains(keyword) ||
          plate.contains(keyword) ||
          technician.contains(keyword) ||
          status.contains(keyword);

      return matchSearch && _matchFilter(item);
    }).toList();
  }

  int _countByStatus(List<String> statuses) {
    return _reports.where((item) {
      final status = _getStatus(item).toLowerCase();

      return statuses.contains(status);
    }).length;
  }

  // -------------------------------------------------------------------
  // ACTIVITY LOGS
  // -------------------------------------------------------------------

  List<String> _getActivityLogs(Map<String, dynamic> item) {
    final List<String> logs = [];

    final damageType = _getDamageType(item);
    final description = _getDescription(item);
    final requestedAt = _getRequestedAt(item);
    final preferredAt = _getPreferredAt(item);
    final scheduledAt = _getScheduledAt(item);
    final estimatedFinishAt = _getEstimatedFinishAt(item);
    final startedAt = _getStartedAt(item);
    final completedAt = _getCompletedAt(item);
    final technicianName = _getTechnicianName(item);
    final noteDriver = _getNoteDriver(item);
    final noteAdmin = _getNoteAdmin(item);
    final noteTechnician = _getNoteTechnician(item);
    final status = _getStatus(item);

    if (damageType != "-") {
      logs.add("Laporan kerusakan: $damageType");
    }

    if (description != "-") {
      logs.add("Deskripsi driver: $description");
    }

    if (requestedAt != "-") {
      logs.add("Laporan / booking dibuat pada: $requestedAt");
    }

    if (preferredAt != "-") {
      logs.add("Preferensi jadwal driver: $preferredAt");
    }

    if (noteDriver != "-") {
      logs.add("Catatan driver: $noteDriver");
    }

    if (scheduledAt != "-") {
      logs.add("Jadwal final admin: $scheduledAt");
    } else {
      logs.add("Menunggu admin menentukan jadwal final.");
    }

    if (estimatedFinishAt != "-") {
      logs.add("Estimasi selesai: $estimatedFinishAt");
    }

    if (noteAdmin != "-") {
      logs.add("Catatan admin: $noteAdmin");
    }

    if (technicianName != "Belum ditugaskan") {
      logs.add("Teknisi ditugaskan: $technicianName");
    } else {
      logs.add("Menunggu admin menugaskan teknisi.");
    }

    if (startedAt != "-") {
      logs.add("Teknisi mulai mengerjakan pada: $startedAt");
    }

    if (completedAt != "-") {
      logs.add("Maintenance selesai pada: $completedAt");
    }

    if (noteTechnician != "-") {
      logs.add("Catatan teknisi: $noteTechnician");
    }

    final responses = _getTechnicianResponses(item);

    for (final responseItem in responses) {
      if (responseItem is Map) {
        final response = Map<String, dynamic>.from(responseItem);

        final statusRaw = response["status"]?.toString();
        final note = response["note"]?.toString();
        final responseAt = response["created_at"]?.toString();

        if (statusRaw != null && statusRaw.isNotEmpty) {
          logs.add("Update teknisi: ${_mapStatusLabel(statusRaw)}");
        }

        if (note != null && note.isNotEmpty) {
          logs.add("Catatan update teknisi: $note");
        }

        if (responseAt != null && responseAt.isNotEmpty) {
          logs.add("Update teknisi pada: ${_formatDateTime(responseAt)}");
        }
      }
    }

    logs.add("Status saat ini: $status");

    if (logs.isEmpty) {
      logs.add("Belum ada aktivitas maintenance.");
    }

    return logs;
  }

  // -------------------------------------------------------------------
  // UI BODY
  // -------------------------------------------------------------------

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

    if (_reports.isEmpty) {
      return _buildEmptyState();
    }

    final filtered = _filteredReports;

    return RefreshIndicator(
      onRefresh: _loadDamageReports,
      color: primaryColor,
      backgroundColor: cardColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          _buildHeaderDashboard(),
          const SizedBox(height: 16),
          _buildSearchBox(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            _buildNoDataFound()
          else
            ...filtered.map((item) {
              final unit = _getUnitName(item);
              final plate = _getPlateNumber(item);
              final status = _getStatus(item);
              final color = _getStatusColor(status);
              final jobs = _getActivityLogs(item);

              return _buildUnitCard(
                context: context,
                report: item,
                unit: unit,
                plate: plate,
                status: status,
                color: color,
                jobs: jobs,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeaderDashboard() {
    final total = _reports.length;
    final waiting = _countByStatus(["requested"]);
    final progress = _countByStatus(["in progress"]);
    final completed = _countByStatus(["completed"]);

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
                icon: Icons.monitor_heart_outlined,
                color: primaryColor,
                size: 52,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Live Unit Tracking",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Pantau proses maintenance dari laporan sampai selesai.",
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
                  title: "Waiting",
                  value: "$waiting",
                  icon: Icons.hourglass_top_rounded,
                  color: Colors.orangeAccent,
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
                  icon: Icons.check_circle_outline,
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
      cursorColor: primaryColor,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        hintText: "Cari unit, plat, teknisi, atau status...",
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
      case "requested":
        return "Requested";
      case "approved":
        return "Approved";
      case "in_progress":
        return "Progress";
      case "completed":
        return "Done";
      case "on_hold":
        return "On Hold";
      case "canceled":
        return "Canceled";
      case "rejected":
        return "Rejected";
      default:
        return value;
    }
  }

  Widget _buildUnitCard({
    required BuildContext context,
    required Map<String, dynamic> report,
    required String unit,
    required String plate,
    required String status,
    required Color color,
    required List<String> jobs,
  }) {
    final bookingId = _getBookingId(report);
    final reportId = _getReportId(report);
    final scheduledAt = _getScheduledAt(report);
    final technicianName = _getTechnicianName(report);
    final damageType = _getDamageType(report);

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
              builder: (context) => UnitTrackingDetailPage(
                item: report,
                unit: unit,
                plateNumber: plate,
                status: status,
                jobs: jobs,
                color: color,
                damageType: damageType,
                description: _getDescription(report),
                createdAt: _getRequestedAt(report),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _iconBadge(
                icon: _getStatusIcon(status),
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
                    const SizedBox(height: 7),
                    Text(
                      "Plate: $plate",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _smallChip(reportId, Colors.white54),
                        _smallChip(bookingId, Colors.white54),
                        _smallChip("Tech: $technicianName", Colors.lightBlueAccent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      scheduledAt == "-"
                          ? "Schedule: menunggu admin"
                          : "Schedule: $scheduledAt",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(status, color),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white30,
                  ),
                ],
              ),
            ],
          ),
        ),
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
                  onPressed: _loadDamageReports,
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
    return RefreshIndicator(
      onRefresh: _loadDamageReports,
      color: primaryColor,
      backgroundColor: cardColor,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            child: Column(
              children: [
                _iconBadge(
                  icon: Icons.track_changes_outlined,
                  color: primaryColor,
                  size: 70,
                ),
                const SizedBox(height: 18),
                const Text(
                  "Belum ada unit tracking",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Setelah driver membuat laporan dan booking maintenance, statusnya akan muncul di sini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
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

  Widget _smallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Unit Tracking",
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
            tooltip: "Refresh",
            onPressed: _loadDamageReports,
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
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
// 2. HALAMAN DETAIL KERJAAN TEKNISI / MAINTENANCE - VIEW ONLY
// -------------------------------------------------------------------
class UnitTrackingDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final String unit;
  final String plateNumber;
  final String status;
  final List<String> jobs;
  final Color color;
  final String damageType;
  final String description;
  final String createdAt;

  const UnitTrackingDetailPage({
    super.key,
    required this.item,
    required this.unit,
    required this.plateNumber,
    required this.status,
    required this.jobs,
    required this.color,
    required this.damageType,
    required this.description,
    required this.createdAt,
  });

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

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
    final nested = _asMap(item["damage_report"]);

    if (nested != null) {
      return nested;
    }

    final camelNested = _asMap(item["damageReport"]);

    if (camelNested != null) {
      return camelNested;
    }

    return item;
  }

  Map<String, dynamic>? _getBooking() {
    final serviceBooking = _asMap(item["service_booking"]);

    if (serviceBooking != null) {
      return serviceBooking;
    }

    final latestServiceBooking = _asMap(item["latest_service_booking"]);

    if (latestServiceBooking != null) {
      return latestServiceBooking;
    }

    final booking = _asMap(item["booking"]);

    if (booking != null) {
      return booking;
    }

    final hasBookingFields = item["scheduled_at"] != null ||
        item["preferred_at"] != null ||
        item["estimated_finish_at"] != null ||
        item["requested_at"] != null ||
        item["started_at"] != null ||
        item["completed_at"] != null ||
        item["damage_report"] != null;

    if (hasBookingFields) {
      return item;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingVehicle = _asMap(booking?["vehicle"]);

    if (bookingVehicle != null) {
      return bookingVehicle;
    }

    final reportVehicle = _asMap(damageReport?["vehicle"]);

    if (reportVehicle != null) {
      return reportVehicle;
    }

    final directVehicle = _asMap(item["vehicle"]);

    if (directVehicle != null) {
      return directVehicle;
    }

    return null;
  }

  Map<String, dynamic>? _getDriver() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingDriver = _asMap(booking?["driver"]);

    if (bookingDriver != null) {
      return bookingDriver;
    }

    final reportDriver = _asMap(damageReport?["driver"]);

    if (reportDriver != null) {
      return reportDriver;
    }

    final directDriver = _asMap(item["driver"]);

    if (directDriver != null) {
      return directDriver;
    }

    return null;
  }

  Map<String, dynamic>? _getTechnician() {
    final booking = _getBooking();

    final technician = _asMap(booking?["technician"]);

    if (technician != null) {
      return technician;
    }

    final mechanic = _asMap(booking?["mechanic"]);

    if (mechanic != null) {
      return mechanic;
    }

    final assignedTechnician = _asMap(booking?["assigned_technician"]);

    if (assignedTechnician != null) {
      return assignedTechnician;
    }

    final assignedTechnicianCamel = _asMap(booking?["assignedTechnician"]);

    if (assignedTechnicianCamel != null) {
      return assignedTechnicianCamel;
    }

    return null;
  }

  Map<String, dynamic>? _getLatestResponse() {
    final damageReport = _getDamageReport();

    final latestFromReport = _asMap(damageReport?["latest_technician_response"]);

    if (latestFromReport != null) {
      return latestFromReport;
    }

    final latestFromReportCamel =
        _asMap(damageReport?["latestTechnicianResponse"]);

    if (latestFromReportCamel != null) {
      return latestFromReportCamel;
    }

    final latestDirect = _asMap(item["latest_technician_response"]);

    if (latestDirect != null) {
      return latestDirect;
    }

    final latestDirectCamel = _asMap(item["latestTechnicianResponse"]);

    if (latestDirectCamel != null) {
      return latestDirectCamel;
    }

    return null;
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final normalized =
          raw.contains(" ") && !raw.contains("T") ? raw.replaceFirst(" ", "T") : raw;

      final date = DateTime.parse(normalized).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, "0");
      final minute = date.minute.toString().padLeft(2, "0");

      return "$day-$month-$year $hour:$minute WIB";
    } catch (_) {
      return raw;
    }
  }

  String _getEquipmentName() {
    final vehicle = _getVehicle();

    return vehicle?["equipment_name"]?.toString() ??
        vehicle?["name"]?.toString() ??
        unit;
  }

  String _getReportId() {
    final damageReport = _getDamageReport();

    final id = damageReport?["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#DR-$id";
  }

  String _getBookingId() {
    final booking = _getBooking();

    final id = booking?["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#BK-$id";
  }

  String _getDriverName() {
    final driver = _getDriver();

    if (driver == null) {
      return "-";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "-";
  }

  String _getTechnicianName() {
    final technician = _getTechnician();

    if (technician == null) {
      return "Belum ditugaskan";
    }

    return technician["name"]?.toString() ??
        technician["username"]?.toString() ??
        "Teknisi";
  }

  String _getRequestedAt() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    return _formatDateTime(
      booking?["requested_at"] ??
          booking?["created_at"] ??
          damageReport?["created_at"] ??
          item["created_at"],
    );
  }

  String _getPreferredAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["preferred_at"]);
  }

  String _getScheduledAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["scheduled_at"]);
  }

  String _getEstimatedFinishAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["estimated_finish_at"]);
  }

  String _getStartedAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["started_at"]);
  }

  String _getCompletedAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["completed_at"]);
  }

  String _getNoteDriver() {
    final booking = _getBooking();

    return booking?["note_driver"]?.toString() ?? "-";
  }

  String _getNoteAdmin() {
    final booking = _getBooking();

    return booking?["note_admin"]?.toString() ?? "-";
  }

  String _getNoteTechnician() {
    final booking = _getBooking();
    final latest = _getLatestResponse();

    return booking?["note_technician"]?.toString() ??
        latest?["note"]?.toString() ??
        latest?["response_note"]?.toString() ??
        "-";
  }

  String _getPriority() {
    final booking = _getBooking();

    return booking?["priority"]?.toString() ?? "-";
  }

  String _getStatusDescription() {
    switch (status.toLowerCase()) {
      case "requested":
        return "Laporan sudah dibuat dan booking maintenance sedang menunggu approval admin.";

      case "approved":
        return "Admin sudah menyetujui booking dan menentukan jadwal. Teknisi akan mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "on hold":
        return "Pekerjaan tertunda dan membutuhkan tindak lanjut admin atau sparepart.";

      case "completed":
        return "Maintenance kendaraan sudah selesai dikerjakan.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Laporan atau booking ditolak.";

      case "fatal":
        return "Unit ditandai mengalami kerusakan fatal.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case "requested":
        return Icons.hourglass_top_rounded;

      case "approved":
        return Icons.event_available_rounded;

      case "rescheduled":
        return Icons.update_rounded;

      case "in progress":
        return Icons.autorenew_rounded;

      case "on hold":
        return Icons.pause_circle_outline_rounded;

      case "completed":
        return Icons.check_circle_rounded;

      case "canceled":
        return Icons.cancel_rounded;

      case "rejected":
        return Icons.block_rounded;

      case "fatal":
        return Icons.report_gmailerrorred_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentName = _getEquipmentName();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Unit Activity",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(equipmentName),
              const SizedBox(height: 16),
              _buildStatusInfoCard(),
              _buildSectionCard(
                title: "Report Information",
                icon: Icons.report_problem_outlined,
                child: Column(
                  children: [
                    _buildInfoGrid([
                      _InfoItem(
                        title: "Damage Type",
                        value: damageType,
                        icon: Icons.build_circle_outlined,
                      ),
                      _InfoItem(
                        title: "Reported At",
                        value: createdAt,
                        icon: Icons.calendar_today_outlined,
                      ),
                      _InfoItem(
                        title: "Driver",
                        value: _getDriverName(),
                        icon: Icons.person_outline_rounded,
                      ),
                      _InfoItem(
                        title: "Priority",
                        value: _getPriority(),
                        icon: Icons.priority_high_rounded,
                      ),
                      _InfoItem(
                        title: "Report ID",
                        value: _getReportId(),
                        icon: Icons.receipt_long_outlined,
                      ),
                      _InfoItem(
                        title: "Booking ID",
                        value: _getBookingId(),
                        icon: Icons.assignment_outlined,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _buildTextBlock(
                      title: "Description",
                      value: description,
                      icon: Icons.description_outlined,
                    ),
                  ],
                ),
              ),
              _buildSectionCard(
                title: "Maintenance Schedule",
                icon: Icons.event_available_outlined,
                child: _buildScheduleTimeline(),
              ),
              _buildSectionCard(
                title: "Notes",
                icon: Icons.notes_outlined,
                child: Column(
                  children: [
                    _buildTextBlock(
                      title: "Driver Note",
                      value: _getNoteDriver(),
                      icon: Icons.drive_eta_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildTextBlock(
                      title: "Admin Note",
                      value: _getNoteAdmin(),
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    const SizedBox(height: 10),
                    _buildTextBlock(
                      title: "Technician Note",
                      value: _getNoteTechnician(),
                      icon: Icons.engineering_outlined,
                      highlight: true,
                    ),
                  ],
                ),
              ),
              _buildSectionCard(
                title: "Maintenance Activities",
                icon: Icons.timeline_rounded,
                child: _buildActivities(),
              ),
              const SizedBox(height: 16),
              _buildViewOnlyCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(String equipmentName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.30),
            cardColor,
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: color.withOpacity(0.22),
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
          _iconBadge(
            icon: _getStatusIcon(),
            color: color,
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipmentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Plate Number: $plateNumber",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${_getReportId()}  •  ${_getBookingId()}",
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _statusChip(status, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getStatusDescription(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softCardColor.withOpacity(0.86),
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
          _sectionTitle(title, icon),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.05,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
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
              child: _buildInfoTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInfoTile(_InfoItem item) {
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
            color: primaryColor,
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

  Widget _buildScheduleTimeline() {
    final items = [
      _ScheduleItem(
        title: "Preferred",
        value: _getPreferredAt(),
        icon: Icons.event_note_outlined,
      ),
      _ScheduleItem(
        title: "Scheduled",
        value: _getScheduledAt() == "-" ? "Menunggu admin" : _getScheduledAt(),
        icon: Icons.event_available_outlined,
      ),
      _ScheduleItem(
        title: "Est. Finish",
        value: _getEstimatedFinishAt(),
        icon: Icons.timer_outlined,
      ),
      _ScheduleItem(
        title: "Technician",
        value: _getTechnicianName(),
        icon: Icons.engineering_outlined,
      ),
      _ScheduleItem(
        title: "Started",
        value: _getStartedAt(),
        icon: Icons.play_circle_outline_rounded,
      ),
      _ScheduleItem(
        title: "Completed",
        value: _getCompletedAt(),
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    return Column(
      children: items.map((item) {
        final empty = item.value == "-";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: empty
                      ? Colors.white.withOpacity(0.06)
                      : color.withOpacity(0.13),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: empty
                        ? Colors.white.withOpacity(0.08)
                        : color.withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: empty ? Colors.white30 : color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.055),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.value,
                        style: TextStyle(
                          color: empty ? Colors.white30 : Colors.white,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextBlock({
    required String title,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? primaryColor.withOpacity(0.08)
            : Colors.white.withOpacity(0.052),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? primaryColor.withOpacity(0.18)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: highlight ? primaryColor : Colors.white38,
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
                    color: highlight ? primaryColor : Colors.white38,
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

  Widget _buildActivities() {
    if (jobs.isEmpty) {
      return _softMessage(
        icon: Icons.timeline_outlined,
        message: "Belum ada aktivitas maintenance.",
        color: Colors.white54,
      );
    }

    return Column(
      children: jobs.asMap().entries.map((entry) {
        final index = entry.key;
        final job = entry.value;
        final isLast = index == jobs.length - 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isLast
                          ? color.withOpacity(0.13)
                          : Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isLast
                            ? color.withOpacity(0.35)
                            : Colors.white.withOpacity(0.10),
                      ),
                    ),
                    child: Icon(
                      isLast
                          ? Icons.flag_circle_outlined
                          : Icons.check_rounded,
                      color: isLast ? color : Colors.white38,
                      size: 16,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1,
                      height: 28,
                      color: Colors.white.withOpacity(0.09),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: Text(
                    job,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildViewOnlyCard() {
    return _softMessage(
      icon: Icons.visibility_rounded,
      message:
          "VIEW ONLY MODE. Driver/operator hanya dapat memantau status. Jadwal ditentukan admin dan pekerjaan diperbarui oleh teknisi.",
      color: Colors.white54,
    );
  }

  Widget _softMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            size: 20,
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
}

class _InfoItem {
  final String title;
  final String value;
  final IconData icon;

  const _InfoItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _ScheduleItem {
  final String title;
  final String value;
  final IconData icon;

  const _ScheduleItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}