import 'package:flutter/material.dart';
import 'package:djatimobile_project/core/services/repair_status_service.dart';

// -------------------------------------------------------------------
// 1. HALAMAN UTAMA: DAFTAR REPAIR / MAINTENANCE STATUS DRIVER
// -------------------------------------------------------------------
class RepairStatusPage extends StatefulWidget {
  const RepairStatusPage({super.key});

  @override
  State<RepairStatusPage> createState() => _RepairStatusPageState();
}

class _RepairStatusPageState extends State<RepairStatusPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadRepairStatus();
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

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final dateTime = DateTime.parse(raw).toLocal();

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return "$day-$month-$year $hour:$minute WIB";
    } catch (e) {
      return raw;
    }
  }

  Future<void> _loadRepairStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await RepairStatusService.getDamageReports();

      debugPrint("TOTAL REPORTS DI UI: ${reports.length}");
      debugPrint("REPORTS UI DATA: $reports");

      if (!mounted) return;

      setState(() {
        _reports = reports;
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

  // -------------------------------------------------------------------
  // NORMALIZER DATA
  // -------------------------------------------------------------------

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> item) {
    final damageReport = _asMap(item["damage_report"]);
    if (damageReport != null) {
      return damageReport;
    }

    return item;
  }

  Map<String, dynamic>? _getBooking(Map<String, dynamic> item) {
    final serviceBooking = _asMap(item["service_booking"]);
    if (serviceBooking != null) {
      return serviceBooking;
    }

    final booking = _asMap(item["booking"]);
    if (booking != null) {
      return booking;
    }

    final latestBooking = _asMap(item["latest_service_booking"]);
    if (latestBooking != null) {
      return latestBooking;
    }

    final hasBookingFields = item["scheduled_at"] != null ||
        item["preferred_at"] != null ||
        item["estimated_finish_at"] != null ||
        item["requested_at"] != null ||
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

    return null;
  }

  Map<String, dynamic>? _getLatestTechnicianResponse(
    Map<String, dynamic> item,
  ) {
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

  String _getDamageType(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    return damageReport?["damage_type"]?.toString() ??
        item["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> item) {
    final damageReport = _getDamageReport(item);

    return damageReport?["description"]?.toString() ??
        item["description"]?.toString() ??
        "-";
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

  String _getCreatedAt(Map<String, dynamic> item) {
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

  String _getTechnicianNote(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final latestResponse = _getLatestTechnicianResponse(item);

    return booking?["note_technician"]?.toString() ??
        latestResponse?["note"]?.toString() ??
        latestResponse?["response_note"]?.toString() ??
        "Belum ada catatan teknisi.";
  }

  String _getRawStatus(Map<String, dynamic> item) {
    final booking = _getBooking(item);
    final damageReport = _getDamageReport(item);
    final latestResponse = _getLatestTechnicianResponse(item);

    return booking?["status"]?.toString() ??
        damageReport?["status"]?.toString() ??
        latestResponse?["status"]?.toString() ??
        item["status"]?.toString() ??
        "reported";
  }

  String _getRepairStatus(Map<String, dynamic> item) {
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

      case "diproses":
      case "proses":
      case "ongoing":
      case "in_progress":
        return "In Progress";

      case "menunggu_sparepart":
      case "waiting_parts":
      case "waiting parts":
      case "on_hold":
      case "on hold":
        return "Waiting Parts";

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

      case "waiting parts":
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

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case "requested":
        return "Booking maintenance sudah diajukan dan menunggu persetujuan admin.";

      case "approved":
        return "Booking sudah disetujui admin. Teknisi akan mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "waiting parts":
        return "Pekerjaan menunggu sparepart atau tindak lanjut.";

      case "completed":
        return "Maintenance kendaraan sudah selesai.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Booking atau laporan ditolak.";

      case "fatal":
        return "Laporan ditandai sebagai kerusakan fatal.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  List<String> _getWorkLogs(Map<String, dynamic> item) {
    final List<String> logs = [];

    final damageType = _getDamageType(item);
    final description = _getDescription(item);
    final createdAt = _getCreatedAt(item);
    final preferredAt = _getPreferredAt(item);
    final scheduledAt = _getScheduledAt(item);
    final estimatedFinishAt = _getEstimatedFinishAt(item);
    final startedAt = _getStartedAt(item);
    final completedAt = _getCompletedAt(item);
    final technicianName = _getTechnicianName(item);
    final noteAdmin = _getNoteAdmin(item);
    final technicianNote = _getTechnicianNote(item);
    final status = _getRepairStatus(item);

    if (damageType != "-" && damageType.isNotEmpty) {
      logs.add("Laporan kerusakan: $damageType");
    }

    if (description != "-" && description.isNotEmpty) {
      logs.add("Deskripsi: $description");
    }

    if (createdAt != "-") {
      logs.add("Laporan dibuat pada: $createdAt");
    }

    if (preferredAt != "-") {
      logs.add("Preferensi jadwal driver: $preferredAt");
    }

    if (scheduledAt != "-") {
      logs.add("Jadwal final admin: $scheduledAt");
    } else {
      logs.add("Menunggu admin menentukan jadwal final");
    }

    if (estimatedFinishAt != "-") {
      logs.add("Estimasi selesai: $estimatedFinishAt");
    }

    if (technicianName != "Belum ditugaskan") {
      logs.add("Teknisi ditugaskan: $technicianName");
    } else {
      logs.add("Menunggu admin menugaskan teknisi");
    }

    if (noteAdmin != "-") {
      logs.add("Catatan admin: $noteAdmin");
    }

    if (startedAt != "-") {
      logs.add("Teknisi mulai kerja pada: $startedAt");
    }

    if (completedAt != "-") {
      logs.add("Maintenance selesai pada: $completedAt");
    }

    if (technicianNote != "Belum ada catatan teknisi." &&
        technicianNote != "-" &&
        technicianNote.isNotEmpty) {
      logs.add("Catatan teknisi: $technicianNote");
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
                onPressed: _loadRepairStatus,
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
        onRefresh: _loadRepairStatus,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.build_circle_outlined,
              color: Colors.white24,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada laporan maintenance",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 8),
            Text(
              "Laporan yang kamu kirim akan muncul di sini setelah dibuat.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepairStatus,
      color: const Color(0xFFF9A825),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Tracking Maintenance Scheduling",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pantau status dari laporan driver, approval admin, sampai teknisi menyelesaikan pekerjaan.",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ..._reports.map((item) {
            final report = Map<String, dynamic>.from(item as Map);

            final unitName = _getUnitName(report);
            final plateNumber = _getPlateNumber(report);
            final status = _getRepairStatus(report);
            final color = _getStatusColor(status);
            final logs = _getWorkLogs(report);

            return _buildRepairCard(
              context: context,
              item: report,
              title: unitName,
              plateNumber: plateNumber,
              status: status,
              color: color,
              logs: logs,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRepairCard({
    required BuildContext context,
    required Map<String, dynamic> item,
    required String title,
    required String plateNumber,
    required String status,
    required Color color,
    required List<String> logs,
  }) {
    final bookingId = _getBookingId(item);
    final scheduledAt = _getScheduledAt(item);
    final technicianName = _getTechnicianName(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RepairDetailViewOnly(
                item: item,
                unitName: title,
                plateNumber: plateNumber,
                status: status,
                statusColor: color,
                workLogs: logs,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Plate Number: $plateNumber",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookingId == "-" ? "Booking: belum dibuat" : "Booking: $bookingId",
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.25)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
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
          "REPAIR STATUS",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }
}

// -------------------------------------------------------------------
// 2. HALAMAN DETAIL: REPAIR / MAINTENANCE PROGRESS VIEW ONLY
// -------------------------------------------------------------------
class RepairDetailViewOnly extends StatelessWidget {
  final Map<String, dynamic> item;
  final String unitName;
  final String plateNumber;
  final String status;
  final Color statusColor;
  final List<String> workLogs;

  const RepairDetailViewOnly({
    super.key,
    required this.item,
    required this.unitName,
    required this.plateNumber,
    required this.status,
    required this.statusColor,
    required this.workLogs,
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
    final damageReport = _asMap(item["damage_report"]);
    if (damageReport != null) {
      return damageReport;
    }

    return item;
  }

  Map<String, dynamic>? _getBooking() {
    final serviceBooking = _asMap(item["service_booking"]);
    if (serviceBooking != null) {
      return serviceBooking;
    }

    final booking = _asMap(item["booking"]);
    if (booking != null) {
      return booking;
    }

    final latestBooking = _asMap(item["latest_service_booking"]);
    if (latestBooking != null) {
      return latestBooking;
    }

    final hasBookingFields = item["scheduled_at"] != null ||
        item["preferred_at"] != null ||
        item["estimated_finish_at"] != null ||
        item["requested_at"] != null ||
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

    return null;
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final dateTime = DateTime.parse(raw).toLocal();

      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return "$day-$month-$year $hour:$minute WIB";
    } catch (e) {
      return raw;
    }
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

  String _getDamageType() {
    final damageReport = _getDamageReport();

    return damageReport?["damage_type"]?.toString() ??
        item["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription() {
    final damageReport = _getDamageReport();

    return damageReport?["description"]?.toString() ??
        item["description"]?.toString() ??
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

  String _getAdminNote() {
    final booking = _getBooking();
    return booking?["note_admin"]?.toString() ?? "-";
  }

  String _getDriverNote() {
    final booking = _getBooking();
    return booking?["note_driver"]?.toString() ?? "-";
  }

  String _getPriority() {
    final booking = _getBooking();
    return booking?["priority"]?.toString() ?? "-";
  }

  String _getStatusDescription() {
    switch (status.toLowerCase()) {
      case "requested":
        return "Booking maintenance sudah diajukan dan menunggu persetujuan admin.";

      case "approved":
        return "Booking sudah disetujui admin. Teknisi akan mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "waiting parts":
        return "Pekerjaan menunggu sparepart atau tindak lanjut.";

      case "completed":
        return "Maintenance kendaraan sudah selesai.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Booking atau laporan ditolak.";

      case "fatal":
        return "Laporan ditandai sebagai kerusakan fatal.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _getVehicle();
    final equipmentName = vehicle?["equipment_name"]?.toString() ?? unitName;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Unit Progress Detail",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                fontSize: 26,
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildStatusInfoCard(),

            const SizedBox(height: 28),

            Row(
              children: [
                _buildInfoBox("DAMAGE", _getDamageType()),
                const SizedBox(width: 14),
                _buildInfoBox("PRIORITY", _getPriority()),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("REQUESTED", _getRequestedAt()),
                const SizedBox(width: 14),
                _buildInfoBox("PREFERRED", _getPreferredAt()),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("SCHEDULED", _getScheduledAt()),
                const SizedBox(width: 14),
                _buildInfoBox("EST. FINISH", _getEstimatedFinishAt()),
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

            const SizedBox(height: 14),

            Row(
              children: [
                _buildInfoBox("TECHNICIAN", _getTechnicianName()),
                const SizedBox(width: 14),
                _buildInfoBox("BOOKING", _getBookingId()),
              ],
            ),

            const SizedBox(height: 28),

            _buildSectionTitle("REPORT DESCRIPTION"),
            const SizedBox(height: 10),
            _buildTextCard(_getDescription()),

            const SizedBox(height: 22),

            _buildSectionTitle("DRIVER NOTE"),
            const SizedBox(height: 10),
            _buildTextCard(_getDriverNote()),

            const SizedBox(height: 22),

            _buildSectionTitle("ADMIN NOTE"),
            const SizedBox(height: 10),
            _buildTextCard(_getAdminNote()),

            const SizedBox(height: 28),

            _buildSectionTitle("MAINTENANCE WORK LOGS"),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workLogs.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        index == workLogs.length - 1
                            ? Icons.flag_circle_outlined
                            : Icons.check_circle_outline,
                        color: index == workLogs.length - 1
                            ? statusColor
                            : Colors.white24,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          workLogs[index],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(color: Colors.white10, height: 40),

            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    color: Colors.white24,
                    size: 24,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "VIEW ONLY MODE",
                    style: TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Driver hanya dapat memantau status. Jadwal final ditentukan admin dan pekerjaan diperbarui oleh teknisi.",
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
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: statusColor,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF9A825),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        fontSize: 13,
      ),
    );
  }

  Widget _buildTextCard(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Text(
        value.isEmpty ? "-" : value,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
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
}