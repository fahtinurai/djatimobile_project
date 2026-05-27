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

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadDamageReports();
  }

  // -------------------------------------------------------------------
  // API
  // -------------------------------------------------------------------

  Future<void> _loadDamageReports() async {
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

        List<dynamic> reports = [];

        if (decoded is List) {
          reports = decoded;
        } else if (decoded is Map<String, dynamic> && decoded["data"] is List) {
          reports = decoded["data"];
        }

        if (!mounted) return;

        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      } else {
        throw Exception("Gagal mengambil unit tracking: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
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

    return null;
  }

  Map<String, dynamic>? _getLatestResponse(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    final latestFromReport = _asMap(damageReport?["latest_technician_response"]);
    if (latestFromReport != null) {
      return latestFromReport;
    }

    final latestDirect = _asMap(item["latest_technician_response"]);
    if (latestDirect != null) {
      return latestDirect;
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
  // STATUS MAINTENANCE SCHEDULING
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
        return Colors.orange;

      case "approved":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in progress":
        return Colors.blue;

      case "on hold":
        return Colors.redAccent;

      case "completed":
        return Colors.green;

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

  // -------------------------------------------------------------------
  // ACTIVITY LOGS
  // -------------------------------------------------------------------

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
                onPressed: _loadDamageReports,
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

    if (_reports.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDamageReports,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.track_changes_outlined,
              color: Colors.white24,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada laporan maintenance untuk ditracking.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 8),
            Text(
              "Setelah driver membuat laporan dan booking maintenance, statusnya akan muncul di sini.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white24,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDamageReports,
      color: const Color(0xFFF9A825),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Live Maintenance Monitoring",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pantau alur dari laporan driver, approval admin, penugasan teknisi, sampai pekerjaan selesai.",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ..._reports.map<Widget>((item) {
            final report = Map<String, dynamic>.from(item as Map);

            final unit = _getUnitName(report);
            final plate = _getPlateNumber(report);
            final status = _getStatus(report);
            final color = _getStatusColor(status);
            final jobs = _getActivityLogs(report);

            return _buildClickableUnit(
              context: context,
              report: report,
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

  Widget _buildClickableUnit({
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                damageType: _getDamageType(report),
                description: _getDescription(report),
                createdAt: _getRequestedAt(report),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Plate: $plate",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$reportId  •  $bookingId",
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scheduledAt == "-"
                          ? "Schedule: menunggu admin"
                          : "Schedule: $scheduledAt",
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Technician: $technicianName",
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
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
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.white24,
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
          "UNIT TRACKING",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
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

    return null;
  }

  Map<String, dynamic>? _getLatestResponse() {
    final damageReport = _getDamageReport();

    final latestFromReport = _asMap(damageReport?["latest_technician_response"]);
    if (latestFromReport != null) {
      return latestFromReport;
    }

    final latestDirect = _asMap(item["latest_technician_response"]);
    if (latestDirect != null) {
      return latestDirect;
    }

    return null;
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

  @override
  Widget build(BuildContext context) {
    final equipmentName = _getEquipmentName();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Unit Activity",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipmentName,
              style: const TextStyle(
                color: Color(0xFFF9A825),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Plate Number: $plateNumber",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "${_getReportId()}  •  ${_getBookingId()}",
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildStatusInfoCard(),

            const SizedBox(height: 30),

            const Text(
              "REPORT INFORMATION",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow("Damage Type", damageType),
                  const SizedBox(height: 12),
                  _infoRow("Reported At", createdAt),
                  const SizedBox(height: 12),
                  _infoRow("Driver", _getDriverName()),
                  const SizedBox(height: 12),
                  _infoRow("Priority", _getPriority()),
                  const SizedBox(height: 16),
                  const Text(
                    "Description",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "MAINTENANCE SCHEDULE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("PREFERRED", _getPreferredAt()),
                const SizedBox(width: 14),
                _buildInfoBox("SCHEDULED", _getScheduledAt()),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("EST. FINISH", _getEstimatedFinishAt()),
                const SizedBox(width: 14),
                _buildInfoBox("TECHNICIAN", _getTechnicianName()),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("STARTED", _getStartedAt()),
                const SizedBox(width: 14),
                _buildInfoBox("COMPLETED", _getCompletedAt()),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "NOTES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 14),

            _buildNoteCard("Driver Note", _getNoteDriver()),
            const SizedBox(height: 12),
            _buildNoteCard("Admin Note", _getNoteAdmin()),
            const SizedBox(height: 12),
            _buildNoteCard("Technician Note", _getNoteTechnician()),

            const SizedBox(height: 34),

            const Text(
              "MAINTENANCE ACTIVITIES",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            if (jobs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Belum ada aktivitas maintenance.",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...jobs.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final job = entry.value;
                final isLast = index == jobs.length - 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isLast
                            ? Icons.flag_circle_outlined
                            : Icons.check_circle_outline,
                        color: isLast ? color : Colors.white24,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          job,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.visibility,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "VIEW ONLY MODE",
                    style: TextStyle(
                      color: Colors.white24,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Driver/operator hanya dapat memantau status. Jadwal ditentukan admin dan pekerjaan diperbarui oleh teknisi.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getStatusDescription(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String title, String value) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.isEmpty ? "-" : value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
    return Row(
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
    );
  }
}