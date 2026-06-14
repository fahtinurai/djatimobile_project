import 'package:flutter/material.dart';
import 'package:djatimobile_project/core/services/service_booking_service.dart';

class RepairStatusPage extends StatefulWidget {
  const RepairStatusPage({super.key});

  @override
  State<RepairStatusPage> createState() => _RepairStatusPageState();
}

class _RepairStatusPageState extends State<RepairStatusPage>
    with WidgetsBindingObserver {
  static const String storageBaseUrl = "http://192.168.18.195:8000/storage";

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _bookings = [];

  String _searchQuery = "";
  String _selectedFilter = "all";

  final List<String> _filters = const [
    "all",
    "requested",
    "scheduled",
    "in_progress",
    "completed",
    "canceled",
    "rejected",
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBookings();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadBookings(showLoading: false);
    }
  }

  Future<void> _loadBookings({
    bool showLoading = true,
  }) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      final bookings = await ServiceBookingService.getMyBookings();

      if (!mounted) return;

      final safeBookings = bookings
          .map((item) => _asMap(item))
          .whereType<Map<String, dynamic>>()
          .toList();

      setState(() {
        _bookings = safeBookings;
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

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> booking) {
    final report = _asMap(booking["damage_report"]);

    if (report != null) {
      return report;
    }

    final camelReport = _asMap(booking["damageReport"]);

    if (camelReport != null) {
      return camelReport;
    }

    final directReport = _asMap(booking["report"]);

    if (directReport != null) {
      return directReport;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> booking) {
    final directVehicle = _asMap(booking["vehicle"]);

    if (directVehicle != null) {
      return directVehicle;
    }

    final report = _getDamageReport(booking);
    final reportVehicle = _asMap(report?["vehicle"]);

    if (reportVehicle != null) {
      return reportVehicle;
    }

    return null;
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> booking) {
    final directDriver = _asMap(booking["driver"]);

    if (directDriver != null) {
      return directDriver;
    }

    final report = _getDamageReport(booking);
    final reportDriver = _asMap(report?["driver"]);

    if (reportDriver != null) {
      return reportDriver;
    }

    return null;
  }

  Map<String, dynamic>? _getTechnician(Map<String, dynamic> booking) {
    final technician = _asMap(booking["technician"]);

    if (technician != null) {
      return technician;
    }

    final mechanic = _asMap(booking["mechanic"]);

    if (mechanic != null) {
      return mechanic;
    }

    final assignedTechnician = _asMap(booking["assigned_technician"]);

    if (assignedTechnician != null) {
      return assignedTechnician;
    }

    final assignedTechnicianCamel = _asMap(booking["assignedTechnician"]);

    if (assignedTechnicianCamel != null) {
      return assignedTechnicianCamel;
    }

    return null;
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

  String _formatNumber(dynamic value, {int fractionDigits = 2}) {
    if (value == null) return "-";

    final raw = value.toString().trim().replaceAll(",", ".");

    if (raw.isEmpty || raw == "null") return "-";

    final number = num.tryParse(raw);

    if (number == null) {
      return value.toString();
    }

    if (number % 1 == 0) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(fractionDigits);
  }

  dynamic _firstAvailableValue(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text != "null" && text != "-") {
        return value;
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _getCandidateMaps(Map<String, dynamic> booking) {
    final result = <Map<String, dynamic>>[];

    void addMap(dynamic value) {
      final map = _asMap(value);
      if (map == null || map.isEmpty) return;

      final exists = result.any((item) => identical(item, map));
      if (!exists) {
        result.add(map);
      }
    }

    addMap(booking);

    addMap(booking["maintenance_result"]);
    addMap(booking["maintenanceResult"]);
    addMap(booking["technician_result"]);
    addMap(booking["technicianResult"]);
    addMap(booking["technician_response"]);
    addMap(booking["technicianResponse"]);
    addMap(booking["latest_technician_response"]);
    addMap(booking["latestTechnicianResponse"]);
    addMap(booking["result"]);

    final report = _getDamageReport(booking);
    addMap(report);

    if (report != null) {
      addMap(report["maintenance_result"]);
      addMap(report["maintenanceResult"]);
      addMap(report["technician_result"]);
      addMap(report["technicianResult"]);
      addMap(report["technician_response"]);
      addMap(report["technicianResponse"]);
      addMap(report["latest_technician_response"]);
      addMap(report["latestTechnicianResponse"]);
      addMap(report["latest_response"]);
      addMap(report["latestResponse"]);
      addMap(report["response"]);
    }

    final vehicle = _getVehicle(booking);
    addMap(vehicle);

    return result;
  }

  dynamic _findValue(
    Map<String, dynamic> booking,
    List<String> keys,
  ) {
    final maps = _getCandidateMaps(booking);

    for (final map in maps) {
      for (final key in keys) {
        if (!map.containsKey(key)) continue;

        final value = map[key];
        final selected = _firstAvailableValue([value]);

        if (selected != null) {
          return selected;
        }
      }
    }

    return null;
  }

  String _getTechnicianNote(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "note_technician",
      "technician_note",
      "note_teknisi",
      "mechanic_note",
      "note",
    ]);

    final text = value?.toString().trim();

    if (text == null || text.isEmpty || text == "null") {
      return "-";
    }

    return text;
  }

  String _getStartedAtText(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "started_at",
      "service_started_at",
      "repair_started_at",
      "maintenance_started_at",
      "start_time",
    ]);

    return _formatDateTime(value);
  }

  String _getCompletedAtText(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "completed_at",
      "finished_at",
      "service_completed_at",
      "repair_completed_at",
      "maintenance_completed_at",
      "finish_time",
      "finished_time",
    ]);

    return _formatDateTime(value);
  }

  String _getUnitName(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    final report = _getDamageReport(booking);

    return report?["equipment_name"]?.toString() ??
        report?["vehicle_equipment_name"]?.toString() ??
        booking["equipment_name"]?.toString() ??
        "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    final report = _getDamageReport(booking);

    return report?["vehicle_plate_number"]?.toString() ??
        booking["plate_number"]?.toString() ??
        "-";
  }

  String _getSerialNumber(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle != null) {
      return vehicle["serial_number"]?.toString() ??
          vehicle["engine_serial_number"]?.toString() ??
          vehicle["machine_serial_number"]?.toString() ??
          "-";
    }

    final report = _getDamageReport(booking);

    return report?["vehicle_serial_number"]?.toString() ??
        booking["serial_number"]?.toString() ??
        "-";
  }

  String _getBrandModel(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle == null) {
      return "-";
    }

    final brand = vehicle["brand"]?.toString() ?? "";
    final model = vehicle["model"]?.toString() ?? "";

    final result = "$brand $model".trim();

    return result.isEmpty ? "-" : result;
  }

  num _getInitialHourMeter(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);
    final report = _getDamageReport(booking);

    final value = vehicle?["initial_hour_meter"] ??
        vehicle?["initial_kpi"] ??
        vehicle?["hour_meter_awal"] ??
        vehicle?["kpi_awal"] ??
        report?["vehicle_initial_hour_meter"] ??
        report?["vehicle_initial_kpi"] ??
        booking["initial_hour_meter"] ??
        booking["initial_kpi"] ??
        0;

    return num.tryParse(value.toString()) ?? 0;
  }

  String _getCurrentHourMeter(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "final_hour_meter",
      "current_hour_meter",
      "latest_hour_meter",
      "hour_meter_terbaru",
      "vehicle_current_hour_meter",
      "vehicle_latest_hour_meter",
    ]);

    return _formatNumber(value);
  }

  String _getLatestMA(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "ma",
      "current_ma",
      "mechanical_availability",
      "vehicle_current_ma",
      "latest_ma",
    ]);

    return _formatNumber(value, fractionDigits: 1);
  }

  String _getMTTR(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "mttr",
      "mean_time_to_repair",
    ]);

    return _formatNumber(value);
  }

  String _getMTBF(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "mtbf",
      "mean_time_between_failures",
    ]);

    return _formatNumber(value);
  }

  String _getTotalRepairTime(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "total_repair_time",
      "repair_time",
      "repair_time_hours",
      "total_repair_hours",
    ]);

    return _formatNumber(value);
  }

  String _getTotalOperationalTime(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "total_operational_time",
      "operational_time",
      "operational_time_hours",
      "total_operational_hours",
    ]);

    return _formatNumber(value);
  }

  String _getFailureCount(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "failure_count",
      "number_of_failures",
      "failures",
    ]);

    return _formatNumber(value);
  }

  String _getActualOperatingHours(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "actual_operating_hours",
      "actual_operation_hours",
      "actual_operational_hours",
    ]);

    return _formatNumber(value);
  }

  String _getBreakdownHours(Map<String, dynamic> booking) {
    final value = _findValue(booking, [
      "breakdown_hours",
      "breakdown_time",
      "breakdown_time_hours",
    ]);

    return _formatNumber(value);
  }

  bool _hasTechnicianResult(Map<String, dynamic> booking) {
    final noteTechnician = _getTechnicianNote(booking);
    final startedAt = _getStartedAtText(booking);
    final completedAt = _getCompletedAtText(booking);

    return noteTechnician != "-" ||
        startedAt != "-" ||
        completedAt != "-" ||
        _getCurrentHourMeter(booking) != "-" ||
        _getTotalRepairTime(booking) != "-" ||
        _getTotalOperationalTime(booking) != "-" ||
        _getFailureCount(booking) != "-" ||
        _getActualOperatingHours(booking) != "-" ||
        _getBreakdownHours(booking) != "-" ||
        _getMTTR(booking) != "-" ||
        _getMTBF(booking) != "-" ||
        _getLatestMA(booking) != "-";
  }

  num _getTargetAvailability(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);
    final report = _getDamageReport(booking);

    final value = vehicle?["target_availability"] ??
        vehicle?["target_ma"] ??
        report?["vehicle_target_availability"] ??
        booking["target_availability"] ??
        booking["target_ma"] ??
        90;

    return num.tryParse(value.toString()) ?? 90;
  }

  String _getVehicleStatus(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);
    final report = _getDamageReport(booking);

    return vehicle?["status"]?.toString() ??
        vehicle?["unit_status"]?.toString() ??
        report?["vehicle_status"]?.toString() ??
        booking["vehicle_status"]?.toString() ??
        "active";
  }

  String _getVehicleStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return "Aktif";
      case "maintenance":
        return "Maintenance";
      case "inactive":
        return "Tidak Aktif";
      default:
        return status;
    }
  }

  Color _getVehicleStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return Colors.greenAccent;
      case "maintenance":
        return Colors.orangeAccent;
      case "inactive":
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  String _getDamageType(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    return report?["damage_type"]?.toString() ??
        booking["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    return report?["description"]?.toString() ??
        booking["description"]?.toString() ??
        "-";
  }

  String _getDriverName(Map<String, dynamic> booking) {
    final driver = _getDriver(booking);

    if (driver == null) {
      return "-";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "-";
  }

  String _getTechnicianName(Map<String, dynamic> booking) {
    final technician = _getTechnician(booking);

    if (technician == null) {
      final technicianName = booking["technician_name"]?.toString() ??
          booking["mechanic_name"]?.toString();

      if (technicianName != null && technicianName.isNotEmpty) {
        return technicianName;
      }

      return "Belum ditugaskan";
    }

    return technician["name"]?.toString() ??
        technician["username"]?.toString() ??
        "Teknisi";
  }

  String _getBookingId(Map<String, dynamic> booking) {
    final id = booking["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#BK-$id";
  }

  String _getReportId(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    final id = report?["id"]?.toString() ??
        booking["damage_report_id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#DR-$id";
  }

  String? _getDamageImageUrl(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    final raw = report?["image_url"]?.toString() ??
        report?["imageUrl"]?.toString() ??
        report?["image"]?.toString() ??
        booking["image_url"]?.toString() ??
        booking["image"]?.toString();

    if (raw == null || raw.isEmpty || raw == "null" || raw == "-") {
      return null;
    }

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw;
    }

    final cleanPath = raw.startsWith("/") ? raw.substring(1) : raw;

    if (cleanPath.startsWith("storage/")) {
      return "http://192.168.18.195:8000/$cleanPath";
    }

    return "$storageBaseUrl/$cleanPath";
  }

  Widget _buildDamageImage(Map<String, dynamic> booking) {
    final imageUrl = _getDamageImageUrl(booking);

    if (imageUrl == null) {
      return Container(
        width: double.infinity,
        height: 165,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.white24,
              size: 42,
            ),
            SizedBox(height: 10),
            Text(
              "Foto laporan tidak tersedia",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: 205,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          headers: const {
            "Accept": "image/*",
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white.withOpacity(0.04),
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.redAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Gagal memuat foto laporan",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    imageUrl,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return "Waiting Admin Schedule";

      case "approved":
      case "scheduled":
        return "Scheduled";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return "In Progress";

      case "completed":
      case "finished":
      case "selesai":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "rejected":
      case "ditolak":
        return "Rejected";

      default:
        return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return "Booking maintenance sudah diajukan dan sedang menunggu admin menentukan jadwal serta teknisi.";

      case "approved":
      case "scheduled":
        return "Admin sudah menyetujui booking dan menentukan jadwal maintenance.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "completed":
      case "finished":
      case "selesai":
        return "Maintenance kendaraan sudah selesai dikerjakan.";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
      case "ditolak":
        return "Booking maintenance ditolak.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return Colors.orangeAccent;

      case "approved":
      case "scheduled":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return Colors.amberAccent;

      case "completed":
      case "finished":
      case "selesai":
        return Colors.greenAccent;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Colors.redAccent;

      case "rejected":
      case "ditolak":
        return Colors.redAccent;

      default:
        return Colors.white54;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return Icons.hourglass_top_rounded;

      case "approved":
      case "scheduled":
        return Icons.event_available_rounded;

      case "rescheduled":
        return Icons.update_rounded;

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return Icons.autorenew_rounded;

      case "completed":
      case "finished":
      case "selesai":
        return Icons.check_circle_rounded;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Icons.cancel_rounded;

      case "rejected":
      case "ditolak":
        return Icons.block_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  bool _canCancelBooking(String status) {
    final lowerStatus = status.toLowerCase();

    return lowerStatus == "requested" ||
        lowerStatus == "approved" ||
        lowerStatus == "scheduled" ||
        lowerStatus == "rescheduled";
  }

  Future<void> _confirmCancelBooking(Map<String, dynamic> booking) async {
    final unitName = _getUnitName(booking);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Batalkan Booking?",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            "Booking maintenance untuk $unitName akan dibatalkan. Jika kerusakan masih perlu ditangani, kamu dapat mengajukan ulang dari laporan yang sama selama backend mengizinkan.",
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Ya, Batalkan",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _cancelBooking(booking);
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final bookingId = int.tryParse(booking["id"]?.toString() ?? "");

    if (bookingId == null) {
      _showSnackBar("ID booking tidak valid.", Colors.red);
      return;
    }

    final status = booking["status"]?.toString().toLowerCase() ?? "";

    if (!_canCancelBooking(status)) {
      _showSnackBar("Booking ini tidak bisa dibatalkan.", Colors.red);
      return;
    }

    try {
      await ServiceBookingService.cancelBooking(bookingId: bookingId);

      if (!mounted) return;

      _showSnackBar("Booking berhasil dibatalkan.", Colors.green);
      await _loadBookings(showLoading: false);
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        e.toString().replaceFirst("Exception: ", ""),
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  List<String> _getTimelineLogs(Map<String, dynamic> booking) {
    final logs = <String>[];

    final damageType = _getDamageType(booking);
    final description = _getDescription(booking);
    final preferredAt = _formatDateTime(booking["preferred_at"]);
    final requestedAt = _formatDateTime(
      booking["requested_at"] ?? booking["created_at"],
    );
    final scheduledAt = _formatDateTime(booking["scheduled_at"]);
    final estimatedFinishAt = _formatDateTime(booking["estimated_finish_at"]);
    final startedAt = _getStartedAtText(booking);
    final completedAt = _getCompletedAtText(booking);

    final noteDriver = booking["note_driver"]?.toString() ?? "-";
    final noteAdmin = booking["note_admin"]?.toString() ?? "-";
    final noteTechnician = _getTechnicianNote(booking);

    final technicianName = _getTechnicianName(booking);
    final statusLabel = _getStatusLabel(
      booking["status"]?.toString() ?? "requested",
    );

    logs.add("Unit: ${_getUnitName(booking)}");
    logs.add("Nomor plat/lambung: ${_getPlateNumber(booking)}");
    logs.add("Serial mesin: ${_getSerialNumber(booking)}");
    logs.add("Hour Meter Awal: ${_formatNumber(_getInitialHourMeter(booking))}");
    logs.add(
      "Target MA: ${_formatNumber(_getTargetAvailability(booking))}%",
    );
    logs.add(
      "Status unit: ${_getVehicleStatusLabel(_getVehicleStatus(booking))}",
    );

    if (damageType != "-") {
      logs.add("Laporan kerusakan: $damageType");
    }

    if (description != "-") {
      logs.add("Deskripsi: $description");
    }

    if (requestedAt != "-") {
      logs.add("Booking diajukan pada: $requestedAt");
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
      logs.add("Teknisi mulai kerja pada: $startedAt");
    }

    if (completedAt != "-") {
      logs.add("Maintenance selesai pada: $completedAt");
    }

    if (noteTechnician != "-") {
      logs.add("Catatan teknisi: $noteTechnician");
    }

    final currentHourMeter = _getCurrentHourMeter(booking);
    final totalRepairTime = _getTotalRepairTime(booking);
    final totalOperationalTime = _getTotalOperationalTime(booking);
    final failureCount = _getFailureCount(booking);
    final actualOperatingHours = _getActualOperatingHours(booking);
    final breakdownHours = _getBreakdownHours(booking);
    final mttr = _getMTTR(booking);
    final mtbf = _getMTBF(booking);
    final latestMA = _getLatestMA(booking);

    if (currentHourMeter != "-") {
      logs.add("Hour meter terbaru dari teknisi: $currentHourMeter");
    }

    if (totalRepairTime != "-") {
      logs.add("Total repair time: $totalRepairTime jam");
    }

    if (totalOperationalTime != "-") {
      logs.add("Total operational time: $totalOperationalTime jam");
    }

    if (failureCount != "-") {
      logs.add("Number of failures: $failureCount");
    }

    if (actualOperatingHours != "-") {
      logs.add("Actual operating hours: $actualOperatingHours jam");
    }

    if (breakdownHours != "-") {
      logs.add("Breakdown hours: $breakdownHours jam");
    }

    if (mttr != "-") {
      logs.add("MTTR hasil backend: $mttr jam");
    }

    if (mtbf != "-") {
      logs.add("MTBF hasil backend: $mtbf jam");
    }

    if (latestMA != "-") {
      logs.add("Mechanical Availability terbaru: $latestMA%");
    }

    logs.add("Status saat ini: $statusLabel");

    return logs;
  }

  bool _statusMatchesFilter(Map<String, dynamic> booking) {
    if (_selectedFilter == "all") return true;

    final status = booking["status"]?.toString().toLowerCase() ?? "requested";

    if (_selectedFilter == "requested") {
      return [
        "requested",
        "pending",
        "reported",
        "menunggu",
      ].contains(status);
    }

    if (_selectedFilter == "scheduled") {
      return [
        "approved",
        "scheduled",
        "rescheduled",
      ].contains(status);
    }

    if (_selectedFilter == "in_progress") {
      return [
        "in_progress",
        "ongoing",
        "proses",
        "diproses",
      ].contains(status);
    }

    if (_selectedFilter == "completed") {
      return [
        "completed",
        "finished",
        "selesai",
      ].contains(status);
    }

    if (_selectedFilter == "canceled") {
      return [
        "canceled",
        "cancelled",
        "dibatalkan",
      ].contains(status);
    }

    if (_selectedFilter == "rejected") {
      return [
        "rejected",
        "ditolak",
      ].contains(status);
    }

    return true;
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final keyword = _searchQuery.trim().toLowerCase();

    return _bookings.where((booking) {
      final unit = _getUnitName(booking).toLowerCase();
      final plate = _getPlateNumber(booking).toLowerCase();
      final serial = _getSerialNumber(booking).toLowerCase();
      final technician = _getTechnicianName(booking).toLowerCase();
      final status = _getStatusLabel(
        booking["status"]?.toString() ?? "requested",
      ).toLowerCase();

      final matchSearch = keyword.isEmpty ||
          unit.contains(keyword) ||
          plate.contains(keyword) ||
          serial.contains(keyword) ||
          technician.contains(keyword) ||
          status.contains(keyword);

      return matchSearch && _statusMatchesFilter(booking);
    }).toList();
  }

  int _countStatus(List<String> statuses) {
    return _bookings.where((booking) {
      final status = booking["status"]?.toString().toLowerCase() ?? "";
      return statuses.contains(status);
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

    if (_bookings.isEmpty) {
      return _buildEmptyState();
    }

    final bookings = _filteredBookings;

    return RefreshIndicator(
      onRefresh: () => _loadBookings(),
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
          if (bookings.isEmpty)
            _buildNoDataFound()
          else
            ...bookings.map((booking) => _buildBookingCard(booking)),
        ],
      ),
    );
  }

  Widget _buildHeaderDashboard() {
    final total = _bookings.length;
    final waiting = _countStatus([
      "requested",
      "pending",
      "reported",
      "menunggu",
    ]);
    final progress = _countStatus([
      "in_progress",
      "ongoing",
      "proses",
      "diproses",
    ]);
    final completed = _countStatus([
      "completed",
      "finished",
      "selesai",
    ]);

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
        children: [
          Row(
            children: [
              _iconBadge(
                icon: Icons.car_repair_rounded,
                color: primaryColor,
                size: 54,
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Maintenance Schedule",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Pantau booking, jadwal admin, teknisi, dan hasil maintenance unit.",
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
        hintText: "Cari unit, plat, serial, teknisi, atau status...",
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
        return "Waiting";
      case "scheduled":
        return "Scheduled";
      case "in_progress":
        return "Progress";
      case "completed":
        return "Completed";
      case "canceled":
        return "Canceled";
      case "rejected":
        return "Rejected";
      default:
        return value;
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final unitName = _getUnitName(booking);
    final plateNumber = _getPlateNumber(booking);
    final serialNumber = _getSerialNumber(booking);
    final brandModel = _getBrandModel(booking);

    final initialHourMeter = _formatNumber(_getInitialHourMeter(booking));
    final currentHourMeter = _getCurrentHourMeter(booking);
    final latestMA = _getLatestMA(booking);
    final targetAvailability = _formatNumber(_getTargetAvailability(booking));
    final vehicleStatus = _getVehicleStatus(booking);
    final vehicleStatusLabel = _getVehicleStatusLabel(vehicleStatus);
    final vehicleStatusColor = _getVehicleStatusColor(vehicleStatus);

    final damageType = _getDamageType(booking);
    final description = _getDescription(booking);

    final status = booking["status"]?.toString() ?? "requested";
    final priority = booking["priority"]?.toString() ?? "medium";

    final preferredAt = _formatDateTime(booking["preferred_at"]);
    final scheduledAt = _formatDateTime(booking["scheduled_at"]);
    final estimatedFinishAt = _formatDateTime(booking["estimated_finish_at"]);
    final startedAt = _getStartedAtText(booking);
    final completedAt = _getCompletedAtText(booking);

    final noteDriver = booking["note_driver"]?.toString() ?? "-";
    final noteAdmin = booking["note_admin"]?.toString() ?? "-";
    final noteTechnician = _getTechnicianNote(booking);

    final technicianName = _getTechnicianName(booking);
    final driverName = _getDriverName(booking);

    final color = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);
    final canCancel = _canCancelBooking(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.28),
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
          iconColor: primaryColor,
          leading: _iconBadge(
            icon: _getStatusIcon(status),
            color: color,
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
                  "$plateNumber • $serialNumber",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${_getReportId(booking)}  •  ${_getBookingId(booking)}",
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
                    _statusChip(statusLabel, color),
                    _miniChip("Priority: $priority"),
                    _miniChip("HM Awal: $initialHourMeter"),
                    if (currentHourMeter != "-")
                      _miniChip("HM Terbaru: $currentHourMeter"),
                    _miniChip("Target MA: $targetAvailability%"),
                    if (latestMA != "-") _miniChip("MA: $latestMA%"),
                    _statusChip(vehicleStatusLabel, vehicleStatusColor),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const SizedBox(height: 8),
            _statusInfoCard(status, color),
            _sectionCard(
              title: "Damage Photo",
              icon: Icons.photo_camera_outlined,
              child: _buildDamageImage(booking),
            ),
            _sectionCard(
              title: "Overview Metrics",
              icon: Icons.analytics_outlined,
              child: _buildInfoGrid([
                _InfoItem(
                  title: "HM Awal",
                  value: initialHourMeter,
                  icon: Icons.speed_outlined,
                ),
                _InfoItem(
                  title: "HM Terbaru",
                  value: currentHourMeter,
                  icon: Icons.av_timer_outlined,
                ),
                _InfoItem(
                  title: "Target MA",
                  value: "$targetAvailability%",
                  icon: Icons.track_changes_outlined,
                ),
                _InfoItem(
                  title: "MA Terbaru",
                  value: latestMA == "-" ? "-" : "$latestMA%",
                  icon: Icons.verified_outlined,
                ),
              ]),
            ),
            _sectionCard(
              title: "Vehicle Detail",
              icon: Icons.local_shipping_outlined,
              child: _buildInfoGrid([
                _InfoItem(
                  title: "Unit",
                  value: unitName,
                  icon: Icons.precision_manufacturing_outlined,
                ),
                _InfoItem(
                  title: "Plat / Lambung",
                  value: plateNumber,
                  icon: Icons.confirmation_number_outlined,
                ),
                _InfoItem(
                  title: "Serial Mesin",
                  value: serialNumber,
                  icon: Icons.qr_code_2_rounded,
                ),
                _InfoItem(
                  title: "Brand / Model",
                  value: brandModel,
                  icon: Icons.category_outlined,
                ),
                _InfoItem(
                  title: "Status Unit",
                  value: vehicleStatusLabel,
                  icon: Icons.info_outline_rounded,
                ),
              ]),
            ),
            _sectionCard(
              title: "Damage Report",
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
                      title: "Driver",
                      value: driverName,
                      icon: Icons.person_outline_rounded,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _textBlock(
                    title: "Description",
                    value: description,
                    icon: Icons.description_outlined,
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: "Schedule",
              icon: Icons.event_available_outlined,
              child: _buildScheduleTimeline(
                preferredAt: preferredAt,
                scheduledAt: scheduledAt == "-" ? "Menunggu admin" : scheduledAt,
                estimatedFinishAt: estimatedFinishAt,
                technicianName: technicianName,
                startedAt: startedAt,
                completedAt: completedAt,
                color: color,
              ),
            ),
            _sectionCard(
              title: "Notes",
              icon: Icons.notes_outlined,
              child: Column(
                children: [
                  _textBlock(
                    title: "Driver Note",
                    value: noteDriver,
                    icon: Icons.drive_eta_outlined,
                  ),
                  const SizedBox(height: 10),
                  _textBlock(
                    title: "Admin Note",
                    value: noteAdmin,
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(height: 10),
                  _textBlock(
                    title: "Tech Note",
                    value: noteTechnician,
                    icon: Icons.engineering_outlined,
                    highlight: true,
                  ),
                ],
              ),
            ),
            _sectionCard(
              title: "Technician Maintenance Result",
              icon: Icons.fact_check_outlined,
              child: _buildTechnicianResultCard(booking),
            ),
            _sectionCard(
              title: "Timeline",
              icon: Icons.timeline_rounded,
              child: Column(
                children: _getTimelineLogs(booking)
                    .map((log) => _timelineItem(log, color))
                    .toList(),
              ),
            ),
            if (canCancel) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _confirmCancelBooking(booking),
                  icon: const Icon(Icons.cancel_outlined, size: 20),
                  label: const Text(
                    "CANCEL BOOKING",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianResultCard(Map<String, dynamic> booking) {
    final startedAt = _getStartedAtText(booking);
    final completedAt = _getCompletedAtText(booking);
    final noteTechnician = _getTechnicianNote(booking);

    final currentHourMeter = _getCurrentHourMeter(booking);
    final totalRepairTime = _getTotalRepairTime(booking);
    final totalOperationalTime = _getTotalOperationalTime(booking);
    final failureCount = _getFailureCount(booking);
    final actualOperatingHours = _getActualOperatingHours(booking);
    final breakdownHours = _getBreakdownHours(booking);
    final mttr = _getMTTR(booking);
    final mtbf = _getMTBF(booking);
    final latestMA = _getLatestMA(booking);

    final isCompleted = [
      "completed",
      "finished",
      "selesai",
    ].contains((booking["status"]?.toString() ?? "").toLowerCase());

    final hasRawMaintenanceData = currentHourMeter != "-" ||
        totalRepairTime != "-" ||
        totalOperationalTime != "-" ||
        failureCount != "-" ||
        actualOperatingHours != "-" ||
        breakdownHours != "-" ||
        mttr != "-" ||
        mtbf != "-" ||
        latestMA != "-";

    if (!_hasTechnicianResult(booking)) {
      return _softMessage(
        icon: Icons.engineering_outlined,
        color: Colors.white54,
        message:
            "Informasi teknisi belum tersedia. Data akan muncul setelah teknisi mulai atau menyelesaikan pekerjaan.",
      );
    }

    return Column(
      children: [
        _buildInfoGrid([
          _InfoItem(
            title: "Started At",
            value: startedAt,
            icon: Icons.play_circle_outline_rounded,
          ),
          _InfoItem(
            title: "Completed At",
            value: completedAt,
            icon: Icons.check_circle_outline_rounded,
          ),
          _InfoItem(
            title: "HM Terbaru",
            value: currentHourMeter,
            icon: Icons.speed_outlined,
          ),
          _InfoItem(
            title: "Repair Time",
            value: totalRepairTime == "-" ? "-" : "$totalRepairTime jam",
            icon: Icons.build_outlined,
          ),
          _InfoItem(
            title: "Operational",
            value:
                totalOperationalTime == "-" ? "-" : "$totalOperationalTime jam",
            icon: Icons.timer_outlined,
          ),
          _InfoItem(
            title: "Failures",
            value: failureCount,
            icon: Icons.warning_amber_outlined,
          ),
          _InfoItem(
            title: "Actual Operating",
            value:
                actualOperatingHours == "-" ? "-" : "$actualOperatingHours jam",
            icon: Icons.settings_suggest_outlined,
          ),
          _InfoItem(
            title: "Breakdown",
            value: breakdownHours == "-" ? "-" : "$breakdownHours jam",
            icon: Icons.car_crash_outlined,
          ),
          _InfoItem(
            title: "MTTR",
            value: mttr == "-" ? "-" : "$mttr jam",
            icon: Icons.handyman_outlined,
          ),
          _InfoItem(
            title: "MTBF",
            value: mtbf == "-" ? "-" : "$mtbf jam",
            icon: Icons.timeline_outlined,
          ),
          _InfoItem(
            title: "MA Terbaru",
            value: latestMA == "-" ? "-" : "$latestMA%",
            icon: Icons.verified_outlined,
          ),
        ]),
        const SizedBox(height: 12),
        _textBlock(
          title: "Catatan Teknisi",
          value: noteTechnician,
          icon: Icons.engineering_outlined,
          highlight: true,
        ),
        if (isCompleted && !hasRawMaintenanceData) ...[
          const SizedBox(height: 12),
          _softMessage(
            icon: Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            message:
                "Status sudah completed, tetapi data maintenance detail belum diterima dari backend. Cek field final_hour_meter, total_repair_time, failure_count, mttr, mtbf, dan ma.",
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleTimeline({
    required String preferredAt,
    required String scheduledAt,
    required String estimatedFinishAt,
    required String technicianName,
    required String startedAt,
    required String completedAt,
    required Color color,
  }) {
    final items = [
      _ScheduleItem(
        title: "Preferred At",
        value: preferredAt,
        icon: Icons.event_note_outlined,
      ),
      _ScheduleItem(
        title: "Scheduled At",
        value: scheduledAt,
        icon: Icons.event_available_outlined,
      ),
      _ScheduleItem(
        title: "Finish Est.",
        value: estimatedFinishAt,
        icon: Icons.timer_outlined,
      ),
      _ScheduleItem(
        title: "Technician",
        value: technicianName,
        icon: Icons.engineering_outlined,
      ),
      _ScheduleItem(
        title: "Started At",
        value: startedAt,
        icon: Icons.play_circle_outline_rounded,
      ),
      _ScheduleItem(
        title: "Completed At",
        value: completedAt,
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    return Column(
      children: items.map((item) {
        final isEmpty = item.value == "-";

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isEmpty
                      ? Colors.white.withOpacity(0.06)
                      : color.withOpacity(0.13),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isEmpty
                        ? Colors.white.withOpacity(0.08)
                        : color.withOpacity(0.35),
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: isEmpty ? Colors.white30 : color,
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
                          color: isEmpty ? Colors.white30 : Colors.white,
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

  Widget _statusInfoCard(String status, Color color) {
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
          color: color.withOpacity(0.18),
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
              _getStatusDescription(status),
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
        color: softCardColor.withOpacity(0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.065),
        ),
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
              child: _infoTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _infoTile(_InfoItem item) {
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

  Widget _textBlock({
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

  Widget _timelineItem(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.35),
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softMessage({
    required IconData icon,
    required Color color,
    required String message,
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

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
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
              color: Colors.redAccent.withOpacity(0.2),
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
                  onPressed: () => _loadBookings(),
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
      onRefresh: () => _loadBookings(),
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
                  icon: Icons.calendar_month_outlined,
                  color: primaryColor,
                  size: 70,
                ),
                const SizedBox(height: 18),
                const Text(
                  "Belum ada booking maintenance",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Booking akan muncul setelah kamu membuat laporan kerusakan dan sistem mengajukannya ke admin.",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Maintenance Schedule",
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
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
            ),
            onPressed: () => _loadBookings(showLoading: false),
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