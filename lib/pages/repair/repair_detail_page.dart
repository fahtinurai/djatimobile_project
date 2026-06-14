import 'package:flutter/material.dart';

class TaskDetailPage extends StatelessWidget {
  final String unitName;
  final String unitId;
  final String userRole;
  final Map<String, dynamic>? report;
  final VoidCallback? onUpdateStatus;

  const TaskDetailPage({
    super.key,
    this.unitName = "Unit",
    this.unitId = "#ID",
    required this.userRole,
    this.report,
    this.onUpdateStatus,
  });

  static const String backendBaseUrl = "http://192.168.18.195:8000";
  static const String storageBaseUrl = "http://192.168.18.195:8000/storage";

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  // =========================================================
  // DATA NORMALIZER
  // =========================================================

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
    final nested = _asMap(report?["damage_report"]);
    if (nested != null) return nested;

    final camelNested = _asMap(report?["damageReport"]);
    if (camelNested != null) return camelNested;

    final directReport = _asMap(report?["report"]);
    if (directReport != null) return directReport;

    return report;
  }

  Map<String, dynamic>? _getBooking() {
    final serviceBooking = _asMap(report?["service_booking"]);
    if (serviceBooking != null) return serviceBooking;

    final latestServiceBooking = _asMap(report?["latest_service_booking"]);
    if (latestServiceBooking != null) return latestServiceBooking;

    final booking = _asMap(report?["booking"]);
    if (booking != null) return booking;

    final hasBookingFields = report?["scheduled_at"] != null ||
        report?["preferred_at"] != null ||
        report?["estimated_finish_at"] != null ||
        report?["requested_at"] != null ||
        report?["started_at"] != null ||
        report?["completed_at"] != null ||
        report?["damage_report"] != null;

    if (hasBookingFields) {
      return report;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingVehicle = _asMap(booking?["vehicle"]);
    if (bookingVehicle != null) return bookingVehicle;

    final reportVehicle = _asMap(damageReport?["vehicle"]);
    if (reportVehicle != null) return reportVehicle;

    final directVehicle = _asMap(report?["vehicle"]);
    if (directVehicle != null) return directVehicle;

    return null;
  }

  Map<String, dynamic>? _getDriver() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingDriver = _asMap(booking?["driver"]);
    if (bookingDriver != null) return bookingDriver;

    final reportDriver = _asMap(damageReport?["driver"]);
    if (reportDriver != null) return reportDriver;

    final directDriver = _asMap(report?["driver"]);
    if (directDriver != null) return directDriver;

    return null;
  }

  Map<String, dynamic>? _getTechnician() {
    final booking = _getBooking();

    final technician = _asMap(booking?["technician"]);
    if (technician != null) return technician;

    final mechanic = _asMap(booking?["mechanic"]);
    if (mechanic != null) return mechanic;

    final assignedTechnician = _asMap(booking?["assigned_technician"]);
    if (assignedTechnician != null) return assignedTechnician;

    final assignedTechnicianCamel = _asMap(booking?["assignedTechnician"]);
    if (assignedTechnicianCamel != null) return assignedTechnicianCamel;

    final user = _asMap(booking?["user"]);
    if (user != null) return user;

    return null;
  }

  Map<String, dynamic>? _getLatestResponse() {
    final damageReport = _getDamageReport();

    final latest = _asMap(damageReport?["latest_technician_response"]);
    if (latest != null) return latest;

    final latestCamel = _asMap(damageReport?["latestTechnicianResponse"]);
    if (latestCamel != null) return latestCamel;

    final directLatest = _asMap(report?["latest_technician_response"]);
    if (directLatest != null) return directLatest;

    final booking = _getBooking();

    final bookingLatest = _asMap(booking?["latest_technician_response"]);
    if (bookingLatest != null) return bookingLatest;

    final bookingLatestCamel = _asMap(booking?["latestTechnicianResponse"]);
    if (bookingLatestCamel != null) return bookingLatestCamel;

    return null;
  }

  List<Map<String, dynamic>> _getCandidateMaps() {
    final result = <Map<String, dynamic>>[];

    void addMap(dynamic value) {
      final map = _asMap(value);
      if (map == null || map.isEmpty) return;

      final exists = result.any((item) => identical(item, map));
      if (!exists) {
        result.add(map);
      }
    }

    final booking = _getBooking();
    final damageReport = _getDamageReport();
    final latest = _getLatestResponse();
    final vehicle = _getVehicle();

    addMap(report);
    addMap(booking);
    addMap(damageReport);
    addMap(latest);
    addMap(vehicle);

    addMap(booking?["maintenance_result"]);
    addMap(booking?["maintenanceResult"]);
    addMap(booking?["technician_result"]);
    addMap(booking?["technicianResult"]);
    addMap(booking?["technician_response"]);
    addMap(booking?["technicianResponse"]);
    addMap(booking?["result"]);

    addMap(damageReport?["maintenance_result"]);
    addMap(damageReport?["maintenanceResult"]);
    addMap(damageReport?["technician_result"]);
    addMap(damageReport?["technicianResult"]);
    addMap(damageReport?["technician_response"]);
    addMap(damageReport?["technicianResponse"]);
    addMap(damageReport?["latest_response"]);
    addMap(damageReport?["latestResponse"]);
    addMap(damageReport?["response"]);

    return result;
  }

  dynamic _findValue(List<String> keys) {
    final maps = _getCandidateMaps();

    for (final map in maps) {
      for (final key in keys) {
        if (!map.containsKey(key)) continue;

        final value = map[key];

        if (value == null) continue;

        final text = value.toString().trim();

        if (text.isNotEmpty && text != "null" && text != "-") {
          return value;
        }
      }
    }

    return null;
  }

  // =========================================================
  // BASIC INFO
  // =========================================================

  String _getUnitName() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          unitName;
    }

    final damageReport = _getDamageReport();

    return damageReport?["equipment_name"]?.toString() ??
        damageReport?["vehicle_equipment_name"]?.toString() ??
        report?["equipment_name"]?.toString() ??
        unitName;
  }

  String _getUnitId() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingId = booking?["id"]?.toString();

    if (bookingId != null && bookingId.isNotEmpty) {
      return "#BK-$bookingId";
    }

    final reportId = damageReport?["id"]?.toString();

    if (reportId != null && reportId.isNotEmpty) {
      return "#DR-$reportId";
    }

    return unitId;
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

  String _getPlateNumber() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    final damageReport = _getDamageReport();

    return damageReport?["vehicle_plate_number"]?.toString() ?? "-";
  }

  String _getSerialNumber() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["serial_number"]?.toString() ??
          vehicle["engine_serial_number"]?.toString() ??
          vehicle["machine_serial_number"]?.toString() ??
          "-";
    }

    final damageReport = _getDamageReport();

    return damageReport?["vehicle_serial_number"]?.toString() ?? "-";
  }

  String _getBrandModel() {
    final vehicle = _getVehicle();

    if (vehicle == null) {
      return "-";
    }

    final brand = vehicle["brand"]?.toString() ?? "";
    final model = vehicle["model"]?.toString() ?? "";

    final result = "$brand $model".trim();

    return result.isEmpty ? "-" : result;
  }

  num _parseNumber(dynamic value, {num fallback = 0}) {
    if (value == null) return fallback;

    final raw = value.toString().trim().replaceAll(",", ".");

    if (raw.isEmpty || raw == "null") return fallback;

    return num.tryParse(raw) ?? fallback;
  }

  String _formatNumber(dynamic value, {int fractionDigits = 2}) {
    if (value == null) return "-";

    final number = _parseNumber(value, fallback: -999999);

    if (number == -999999) {
      return value.toString();
    }

    if (number % 1 == 0) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(fractionDigits);
  }

  num _getInitialHourMeter() {
    final vehicle = _getVehicle();
    final damageReport = _getDamageReport();

    final value = vehicle?["initial_hour_meter"] ??
        vehicle?["initial_kpi"] ??
        vehicle?["hour_meter_awal"] ??
        vehicle?["kpi_awal"] ??
        damageReport?["vehicle_initial_hour_meter"] ??
        damageReport?["vehicle_initial_kpi"] ??
        report?["initial_hour_meter"] ??
        report?["initial_kpi"] ??
        0;

    return _parseNumber(value);
  }

  num _getTargetAvailability() {
    final vehicle = _getVehicle();
    final damageReport = _getDamageReport();

    final value = vehicle?["target_availability"] ??
        vehicle?["target_ma"] ??
        damageReport?["vehicle_target_availability"] ??
        report?["target_availability"] ??
        report?["target_ma"] ??
        90;

    return _parseNumber(value, fallback: 90);
  }

  String _getVehicleStatus() {
    final vehicle = _getVehicle();
    final damageReport = _getDamageReport();

    return vehicle?["status"]?.toString() ??
        vehicle?["unit_status"]?.toString() ??
        damageReport?["vehicle_status"]?.toString() ??
        report?["vehicle_status"]?.toString() ??
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

  String _getDriverName() {
    final driver = _getDriver();

    if (driver != null) {
      return driver["name"]?.toString() ??
          driver["username"]?.toString() ??
          "Unknown Driver";
    }

    return "Unknown Driver";
  }

  String _getTechnicianName() {
    final technician = _getTechnician();

    if (technician != null) {
      return technician["name"]?.toString() ??
          technician["username"]?.toString() ??
          "Assigned";
    }

    return "Belum ditugaskan";
  }

  String _getDamageType() {
    final damageReport = _getDamageReport();

    return damageReport?["damage_type"]?.toString() ??
        report?["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription() {
    final damageReport = _getDamageReport();

    return damageReport?["description"]?.toString() ??
        damageReport?["note"]?.toString() ??
        report?["description"]?.toString() ??
        "Unit requires immediate attention.";
  }

  String _getNoteDriver() {
    final booking = _getBooking();

    return booking?["note_driver"]?.toString() ?? "-";
  }

  String _getNoteAdmin() {
    final booking = _getBooking();

    return booking?["note_admin"]?.toString() ?? "-";
  }

  String _getPriority() {
    final booking = _getBooking();

    return booking?["priority"]?.toString() ?? "-";
  }

  // =========================================================
  // MAINTENANCE RESULT
  // =========================================================

  String _getCurrentHourMeter() {
    final value = _findValue([
      "final_hour_meter",
      "current_hour_meter",
      "latest_hour_meter",
      "hour_meter_terbaru",
      "vehicle_current_hour_meter",
      "vehicle_latest_hour_meter",
    ]);

    return _formatNumber(value);
  }

  String _getTotalRepairTime() {
    final value = _findValue([
      "total_repair_time",
      "repair_time",
      "repair_time_hours",
      "total_repair_hours",
    ]);

    return _formatNumber(value);
  }

  String _getTotalOperationalTime() {
    final value = _findValue([
      "total_operational_time",
      "operational_time",
      "operational_time_hours",
      "total_operational_hours",
    ]);

    return _formatNumber(value);
  }

  String _getFailureCount() {
    final value = _findValue([
      "failure_count",
      "number_of_failures",
      "failures",
    ]);

    return _formatNumber(value);
  }

  String _getActualOperatingHours() {
    final value = _findValue([
      "actual_operating_hours",
      "actual_operation_hours",
      "actual_operational_hours",
    ]);

    return _formatNumber(value);
  }

  String _getBreakdownHours() {
    final value = _findValue([
      "breakdown_hours",
      "breakdown_time",
      "breakdown_time_hours",
    ]);

    return _formatNumber(value);
  }

  String _getMTTR() {
    final value = _findValue([
      "mttr",
      "mean_time_to_repair",
    ]);

    return _formatNumber(value);
  }

  String _getMTBF() {
    final value = _findValue([
      "mtbf",
      "mean_time_between_failures",
    ]);

    return _formatNumber(value);
  }

  String _getLatestMA() {
    final value = _findValue([
      "ma",
      "current_ma",
      "mechanical_availability",
      "vehicle_current_ma",
      "latest_ma",
    ]);

    return _formatNumber(value, fractionDigits: 1);
  }

  bool _hasMaintenanceResult() {
    return _getCurrentHourMeter() != "-" ||
        _getTotalRepairTime() != "-" ||
        _getTotalOperationalTime() != "-" ||
        _getFailureCount() != "-" ||
        _getActualOperatingHours() != "-" ||
        _getBreakdownHours() != "-" ||
        _getMTTR() != "-" ||
        _getMTBF() != "-" ||
        _getLatestMA() != "-" ||
        _getTechnicianNote() != "Belum ada catatan teknisi.";
  }

  // =========================================================
  // IMAGE
  // =========================================================

  String? _getDamageImageUrl() {
    final damageReport = _getDamageReport();

    final raw = damageReport?["image_url"]?.toString() ??
        damageReport?["imageUrl"]?.toString() ??
        damageReport?["image"]?.toString() ??
        report?["image_url"]?.toString() ??
        report?["image"]?.toString();

    if (raw == null || raw.isEmpty || raw == "null" || raw == "-") {
      return null;
    }

    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      return raw
          .replaceFirst("http://127.0.0.1:8000", backendBaseUrl)
          .replaceFirst("http://localhost:8000", backendBaseUrl);
    }

    final cleanPath = raw.startsWith("/") ? raw.substring(1) : raw;

    if (cleanPath.startsWith("storage/")) {
      return "$backendBaseUrl/$cleanPath";
    }

    return "$storageBaseUrl/$cleanPath";
  }

  // =========================================================
  // DATE FORMATTER
  // =========================================================

  String _formatDateTime(dynamic rawValue, {bool withWib = true}) {
    final raw = rawValue?.toString();

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

      return withWib
          ? "$day-$month-$year $hour:$minute WIB"
          : "$day-$month-$year $hour:$minute";
    } catch (_) {
      return raw;
    }
  }

  String _getCreatedAt() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    return _formatDateTime(
      booking?["created_at"] ??
          booking?["requested_at"] ??
          damageReport?["created_at"] ??
          report?["created_at"],
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

    final value = _findValue([
      "started_at",
      "service_started_at",
      "repair_started_at",
      "maintenance_started_at",
      "start_time",
    ]);

    return _formatDateTime(value ?? booking?["started_at"]);
  }

  String _getCompletedAt() {
    final booking = _getBooking();

    final value = _findValue([
      "completed_at",
      "finished_at",
      "service_completed_at",
      "repair_completed_at",
      "maintenance_completed_at",
      "finish_time",
      "finished_time",
    ]);

    return _formatDateTime(value ?? booking?["completed_at"]);
  }

  // =========================================================
  // STATUS
  // =========================================================

  String _getRawStatus() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();
    final latest = _getLatestResponse();

    return booking?["status"]?.toString() ??
        damageReport?["computed_status"]?.toString() ??
        damageReport?["status"]?.toString() ??
        latest?["status"]?.toString() ??
        report?["status"]?.toString() ??
        "reported";
  }

  String _getStatus() {
    final status = _getRawStatus().toLowerCase();

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
        return _getRawStatus();
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

  String _getStatusDescription() {
    final status = _getStatus().toLowerCase();

    switch (status) {
      case "requested":
        return "Booking maintenance sudah diajukan oleh driver dan menunggu approval admin.";

      case "approved":
        return "Booking sudah disetujui admin. Teknisi dapat mulai mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "on hold":
        return "Pekerjaan tertunda dan membutuhkan tindak lanjut.";

      case "completed":
        return "Maintenance telah selesai dikerjakan.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Booking atau laporan ditolak.";

      case "fatal":
        return "Unit ditandai mengalami kerusakan fatal.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  String _getTechnicianNote() {
    final latest = _getLatestResponse();

    if (latest != null) {
      return latest["note"]?.toString() ??
          latest["response_note"]?.toString() ??
          "-";
    }

    final booking = _getBooking();

    final value = booking?["note_technician"] ??
        booking?["technician_note"] ??
        booking?["note_teknisi"] ??
        _findValue([
          "note_technician",
          "technician_note",
          "note_teknisi",
          "mechanic_note",
        ]);

    if (value == null || value.toString().trim().isEmpty) {
      return "Belum ada catatan teknisi.";
    }

    return value.toString();
  }

  bool get _isMechanic {
    final role = userRole.toUpperCase();

    return role == "MECHANIC" || role == "TEKNISI" || role == "TECHNICIAN";
  }

  bool get _isAdmin {
    return userRole.toUpperCase() == "ADMIN";
  }

  bool get _isDriver {
    return userRole.toUpperCase() == "DRIVER" ||
        userRole.toUpperCase() == "OPERATOR";
  }

  bool get _isFinished {
    final status = _getStatus().toLowerCase();

    return status == "completed" ||
        status == "finished" ||
        status == "canceled" ||
        status == "rejected";
  }

  bool get _canShowActionButton {
    return (_isMechanic || _isAdmin) && onUpdateStatus != null;
  }

  String _getActionButtonText() {
    final status = _getStatus().toLowerCase();

    if (_isAdmin) {
      if (status == "requested") {
        return "APPROVE / SCHEDULE";
      }

      if (status == "approved" || status == "rescheduled") {
        return "RESCHEDULE / CANCEL";
      }

      return "UPDATE BOOKING";
    }

    if (_isMechanic) {
      if (status == "approved" || status == "rescheduled") {
        return "START JOB";
      }

      if (status == "in progress") {
        return "COMPLETE JOB";
      }

      if (_isFinished) {
        return "TASK COMPLETED";
      }

      return "UPDATE STATUS";
    }

    return "UPDATE STATUS";
  }

  List<String> _getTimelineLogs() {
    final logs = <String>[];

    logs.add("Unit: ${_getUnitName()}");
    logs.add("Nomor plat/lambung: ${_getPlateNumber()}");
    logs.add("Serial mesin: ${_getSerialNumber()}");
    logs.add("Hour Meter Awal: ${_formatNumber(_getInitialHourMeter())}");
    logs.add("Target MA: ${_formatNumber(_getTargetAvailability())}%");
    logs.add("Status unit: ${_getVehicleStatusLabel(_getVehicleStatus())}");

    if (_getDamageType() != "-") {
      logs.add("Laporan kerusakan: ${_getDamageType()}");
    }

    if (_getDescription() != "-") {
      logs.add("Deskripsi: ${_getDescription()}");
    }

    if (_getCreatedAt() != "-") {
      logs.add("Dibuat pada: ${_getCreatedAt()}");
    }

    if (_getPreferredAt() != "-") {
      logs.add("Preferensi jadwal driver: ${_getPreferredAt()}");
    }

    if (_getScheduledAt() != "-") {
      logs.add("Jadwal final admin: ${_getScheduledAt()}");
    } else {
      logs.add("Menunggu admin menentukan jadwal final.");
    }

    if (_getEstimatedFinishAt() != "-") {
      logs.add("Estimasi selesai: ${_getEstimatedFinishAt()}");
    }

    if (_getTechnicianName() != "Belum ditugaskan") {
      logs.add("Teknisi ditugaskan: ${_getTechnicianName()}");
    } else {
      logs.add("Menunggu admin menugaskan teknisi.");
    }

    if (_getStartedAt() != "-") {
      logs.add("Teknisi mulai kerja pada: ${_getStartedAt()}");
    }

    if (_getCompletedAt() != "-") {
      logs.add("Maintenance selesai pada: ${_getCompletedAt()}");
    }

    if (_getLatestMA() != "-") {
      logs.add("Mechanical Availability terbaru: ${_getLatestMA()}%");
    }

    logs.add("Status saat ini: ${_getStatus()}");

    return logs;
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final unit = _getUnitName();
    final id = _getUnitId();
    final status = _getStatus();
    final statusColor = _getStatusColor(status);
    final vehicleStatus = _getVehicleStatus();
    final vehicleStatusColor = _getVehicleStatusColor(vehicleStatus);
    final imageUrl = _getDamageImageUrl();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Task Detail",
          style: TextStyle(
            color: primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
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
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            _canShowActionButton ? 110 : 30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(
                unit: unit,
                id: id,
                status: status,
                statusColor: statusColor,
                vehicleStatus: vehicleStatus,
                vehicleStatusColor: vehicleStatusColor,
              ),
              const SizedBox(height: 16),

              _buildStatusInfoCard(statusColor),
              const SizedBox(height: 16),

              _buildSectionCard(
                title: "Damage Photo",
                icon: Icons.photo_camera_outlined,
                child: _buildDamageImage(imageUrl),
              ),

              _buildSectionCard(
                title: "Quick Performance",
                icon: Icons.analytics_outlined,
                child: _buildInfoGrid([
                  _InfoItem(
                    title: "HM Awal",
                    value: _formatNumber(_getInitialHourMeter()),
                    icon: Icons.speed_outlined,
                  ),
                  _InfoItem(
                    title: "Target MA",
                    value: "${_formatNumber(_getTargetAvailability())}%",
                    icon: Icons.track_changes_outlined,
                  ),
                  _InfoItem(
                    title: "HM Terbaru",
                    value: _getCurrentHourMeter(),
                    icon: Icons.av_timer_outlined,
                  ),
                  _InfoItem(
                    title: "MA Terbaru",
                    value: _getLatestMA() == "-" ? "-" : "${_getLatestMA()}%",
                    icon: Icons.verified_outlined,
                  ),
                ]),
              ),

              _buildSectionCard(
                title: "Vehicle Information",
                icon: Icons.local_shipping_outlined,
                child: _buildInfoGrid([
                  _InfoItem(
                    title: "Plate / Lambung",
                    value: _getPlateNumber(),
                    icon: Icons.confirmation_number_outlined,
                  ),
                  _InfoItem(
                    title: "Serial Mesin",
                    value: _getSerialNumber(),
                    icon: Icons.qr_code_2_rounded,
                  ),
                  _InfoItem(
                    title: "Brand / Model",
                    value: _getBrandModel(),
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                  _InfoItem(
                    title: "Unit Status",
                    value: _getVehicleStatusLabel(vehicleStatus),
                    icon: Icons.info_outline_rounded,
                  ),
                ]),
              ),

              _buildSectionCard(
                title: "Report Summary",
                icon: Icons.report_problem_outlined,
                child: Column(
                  children: [
                    _buildInfoGrid([
                      _InfoItem(
                        title: "Created At",
                        value: _getCreatedAt(),
                        icon: Icons.calendar_today_outlined,
                      ),
                      _InfoItem(
                        title: "Damage Type",
                        value: _getDamageType(),
                        icon: Icons.build_circle_outlined,
                      ),
                      _InfoItem(
                        title: "Driver",
                        value: _getDriverName(),
                        icon: Icons.person_outline_rounded,
                      ),
                      _InfoItem(
                        title: "Technician",
                        value: _getTechnicianName(),
                        icon: Icons.engineering_outlined,
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
                      value: _getDescription(),
                      icon: Icons.description_outlined,
                    ),
                  ],
                ),
              ),

              _buildSectionCard(
                title: "Maintenance Schedule",
                icon: Icons.event_available_outlined,
                child: _buildTimelineSchedule(statusColor),
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
                      value: _getTechnicianNote(),
                      icon: Icons.engineering_outlined,
                      highlight: true,
                    ),
                  ],
                ),
              ),

              _buildSectionCard(
                title: "Technician Maintenance Result",
                icon: Icons.fact_check_outlined,
                child: _buildMaintenanceResult(statusColor),
              ),

              _buildSectionCard(
                title: "Timeline",
                icon: Icons.timeline_rounded,
                child: Column(
                  children: _getTimelineLogs()
                      .map((item) => _buildTimelineItem(item, statusColor))
                      .toList(),
                ),
              ),

              _buildSectionCard(
                title: "Access Information",
                icon: Icons.security_outlined,
                child: _buildInfoGrid([
                  _InfoItem(
                    title: "View As",
                    value: userRole.toUpperCase(),
                    icon: Icons.remove_red_eye_outlined,
                  ),
                  _InfoItem(
                    title: "Flow",
                    value: "Assignment",
                    icon: Icons.account_tree_outlined,
                  ),
                ]),
              ),

              if (_isDriver) ...[
                const SizedBox(height: 8),
                _buildSoftMessage(
                  icon: Icons.info_outline_rounded,
                  message:
                      "Driver dapat memantau status booking setelah admin menjadwalkan teknisi.",
                  color: Colors.lightBlueAccent,
                ),
              ],

              if (!_isDriver && !_isMechanic && !_isAdmin) ...[
                const SizedBox(height: 8),
                _buildSoftMessage(
                  icon: Icons.visibility_outlined,
                  message: "Viewing mode only.",
                  color: Colors.white54,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _canShowActionButton
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isFinished ? null : onUpdateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.white12,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      _isFinished
                          ? Icons.lock_outline_rounded
                          : Icons.update_rounded,
                      color: _isFinished ? Colors.white38 : Colors.black,
                    ),
                    label: Text(
                      _isFinished ? "TASK CLOSED" : _getActionButtonText(),
                      style: TextStyle(
                        color: _isFinished ? Colors.white38 : Colors.black,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeroCard({
    required String unit,
    required String id,
    required String status,
    required Color statusColor,
    required String vehicleStatus,
    required Color vehicleStatusColor,
  }) {
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
        border: Border.all(color: primaryColor.withOpacity(0.20)),
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
                icon: _getStatusIcon(status),
                color: statusColor,
                size: 52,
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
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      id,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(status, statusColor),
              _buildChip(
                _getVehicleStatusLabel(vehicleStatus),
                vehicleStatusColor,
              ),
              _buildChip(
                "Priority: ${_getPriority()}",
                Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfoCard(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.12),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: statusColor,
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
        border: Border.all(color: Colors.white.withOpacity(0.065)),
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
          _buildSectionTitle(title, icon),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
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
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            color: primaryColor.withOpacity(0.95),
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

  Widget _buildTimelineSchedule(Color color) {
    final items = [
      _ScheduleItem(
        title: "Preferred At",
        value: _getPreferredAt(),
        icon: Icons.event_note_outlined,
      ),
      _ScheduleItem(
        title: "Scheduled At",
        value: _getScheduledAt() == "-" ? "Menunggu admin" : _getScheduledAt(),
        icon: Icons.event_available_outlined,
      ),
      _ScheduleItem(
        title: "Estimated Finish",
        value: _getEstimatedFinishAt(),
        icon: Icons.timer_outlined,
      ),
      _ScheduleItem(
        title: "Started At",
        value: _getStartedAt(),
        icon: Icons.play_circle_outline_rounded,
      ),
      _ScheduleItem(
        title: "Completed At",
        value: _getCompletedAt(),
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

  Widget _buildMaintenanceResult(Color color) {
    if (!_hasMaintenanceResult()) {
      return _buildSoftMessage(
        icon: Icons.engineering_outlined,
        message:
            "Informasi teknisi belum tersedia. Data akan muncul setelah teknisi mulai atau menyelesaikan pekerjaan.",
        color: Colors.white54,
      );
    }

    return Column(
      children: [
        _buildInfoGrid([
          _InfoItem(
            title: "HM Terbaru",
            value: _getCurrentHourMeter(),
            icon: Icons.speed_outlined,
          ),
          _InfoItem(
            title: "Repair Time",
            value: _getTotalRepairTime() == "-"
                ? "-"
                : "${_getTotalRepairTime()} jam",
            icon: Icons.build_circle_outlined,
          ),
          _InfoItem(
            title: "Operational",
            value: _getTotalOperationalTime() == "-"
                ? "-"
                : "${_getTotalOperationalTime()} jam",
            icon: Icons.timer_outlined,
          ),
          _InfoItem(
            title: "Failures",
            value: _getFailureCount(),
            icon: Icons.warning_amber_outlined,
          ),
          _InfoItem(
            title: "Actual Operating",
            value: _getActualOperatingHours() == "-"
                ? "-"
                : "${_getActualOperatingHours()} jam",
            icon: Icons.settings_suggest_outlined,
          ),
          _InfoItem(
            title: "Breakdown",
            value: _getBreakdownHours() == "-"
                ? "-"
                : "${_getBreakdownHours()} jam",
            icon: Icons.car_crash_outlined,
          ),
          _InfoItem(
            title: "MTTR",
            value: _getMTTR() == "-" ? "-" : "${_getMTTR()} jam",
            icon: Icons.handyman_outlined,
          ),
          _InfoItem(
            title: "MTBF",
            value: _getMTBF() == "-" ? "-" : "${_getMTBF()} jam",
            icon: Icons.timeline_outlined,
          ),
          _InfoItem(
            title: "MA Terbaru",
            value: _getLatestMA() == "-" ? "-" : "${_getLatestMA()}%",
            icon: Icons.verified_outlined,
          ),
        ]),
      ],
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

  Widget _buildTimelineItem(String text, Color color) {
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
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 14,
              color: color,
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

  Widget _buildDamageImage(String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        width: double.infinity,
        height: 170,
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
        height: 220,
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

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
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
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }

  Widget _buildSoftMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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