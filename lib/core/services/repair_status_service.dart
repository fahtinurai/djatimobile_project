import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class RepairStatusService {
  static const String baseUrl = "http://10.0.2.2:8000/api";
  static const String backendBaseUrl = "http://192.168.18.195:8000";
  static const String storageBaseUrl = "http://192.168.18.195:8000/storage";

  // ---------------------------------------------------------------------------
  // MAIN ENDPOINTS
  // ---------------------------------------------------------------------------

  /// Mengambil daftar status repair milik driver.
  ///
  /// Endpoint utama:
  /// GET /api/driver/bookings
  ///
  /// Fallback legacy:
  /// GET /api/driver/damage-reports
  static Future<List<dynamic>> getDamageReports() async {
    try {
      final bookings = await getServiceBookings();

      if (bookings.isNotEmpty) {
        return bookings;
      }
    } catch (e) {
      debugPrint("GET DRIVER BOOKINGS FALLBACK ERROR: $e");
    }

    return getDamageReportsLegacy();
  }

  /// Mengambil status repair dari service bookings.
  static Future<List<dynamic>> getServiceBookings() async {
    final decoded = await _getDecoded("/driver/bookings");
    final list = _extractList(decoded);

    return _normalizeReportList(list);
  }

  /// Endpoint lama.
  static Future<List<dynamic>> getDamageReportsLegacy() async {
    final decoded = await _getDecoded("/driver/damage-reports");
    final list = _extractList(decoded);

    return _normalizeReportList(list);
  }

  /// Alias agar bisa dipakai untuk halaman analytics/tracking juga.
  static Future<List<dynamic>> getMaintenanceTracking() {
    return getDamageReports();
  }

  /// Hanya laporan / booking yang masih aktif.
  static Future<List<dynamic>> getActiveRepairStatuses() async {
    final reports = await getDamageReports();

    return reports.where((item) {
      if (item is! Map) return false;

      final report = Map<String, dynamic>.from(item);
      final status = _getNormalizedStatus(report).toLowerCase();

      return status == "menunggu" ||
          status == "requested" ||
          status == "pending" ||
          status == "reported" ||
          status == "approved" ||
          status == "scheduled" ||
          status == "rescheduled" ||
          status == "proses" ||
          status == "in_progress" ||
          status == "ongoing" ||
          status == "butuh_followup_admin" ||
          status == "waiting_parts" ||
          status == "on_hold";
    }).toList();
  }

  /// Hanya laporan / booking selesai / batal / ditolak.
  static Future<List<dynamic>> getCompletedRepairStatuses() async {
    final reports = await getDamageReports();

    return reports.where((item) {
      if (item is! Map) return false;

      final report = Map<String, dynamic>.from(item);
      final status = _getNormalizedStatus(report).toLowerCase();

      return status == "selesai" ||
          status == "completed" ||
          status == "finished" ||
          status == "done" ||
          status == "closed" ||
          status == "canceled" ||
          status == "cancelled" ||
          status == "dibatalkan" ||
          status == "rejected" ||
          status == "ditolak";
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // HTTP HELPER
  // ---------------------------------------------------------------------------

  static Future<dynamic> _getDecoded(String endpoint) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final uri = Uri.parse("$baseUrl$endpoint");

    debugPrint("REPAIR STATUS GET URL: $uri");

    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    debugPrint("REPAIR STATUS CODE: ${response.statusCode}");
    debugPrint("REPAIR STATUS BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (response.statusCode == 401) {
      throw Exception("Sesi login sudah berakhir. Silakan login ulang.");
    }

    if (response.statusCode == 403) {
      throw Exception("Akun ini tidak memiliki akses sebagai driver.");
    }

    throw Exception(_extractErrorMessage(decoded, response.body));
  }

  // ---------------------------------------------------------------------------
  // NORMALIZER
  // ---------------------------------------------------------------------------

  static List<dynamic> _normalizeReportList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizeReportItem(item);
      }

      if (item is Map) {
        return _normalizeReportItem(Map<String, dynamic>.from(item));
      }

      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizeReportItem(Map<String, dynamic> item) {
    final normalized = Map<String, dynamic>.from(item);

    final damageReport = _extractDamageReport(normalized);
    final booking = _extractBooking(normalized);
    final maintenanceResult = _extractMaintenanceResult(
      normalized,
      damageReport,
      booking,
    );
    final vehicle = _extractVehicle(normalized, damageReport, booking);
    final technician = _extractTechnician(normalized, booking, maintenanceResult);
    final driver = _extractDriver(normalized, damageReport, booking);

    final normalizedDamageReport =
        damageReport == null ? null : _normalizeDamageReport(damageReport);

    final normalizedVehicle =
        vehicle == null ? null : _normalizeVehicle(vehicle);

    final normalizedMaintenance = maintenanceResult == null
        ? null
        : _normalizeMaintenanceResult(maintenanceResult);

    final normalizedBooking = booking == null
        ? null
        : _normalizeBooking(
            booking,
            normalizedVehicle,
            normalizedMaintenance,
            normalizedDamageReport,
          );

    final normalizedTechnician = technician == null
        ? null
        : Map<String, dynamic>.from(technician);

    final normalizedDriver =
        driver == null ? null : Map<String, dynamic>.from(driver);

    // -------------------------------------------------------------------------
    // Attach nested objects
    // -------------------------------------------------------------------------

    if (normalizedDamageReport != null) {
      normalized["damage_report"] = normalizedDamageReport;
      normalized["damageReport"] = normalizedDamageReport;
    }

    if (normalizedVehicle != null) {
      normalized["vehicle"] = normalizedVehicle;

      if (normalized["damage_report"] is Map) {
        final reportMap = Map<String, dynamic>.from(
          normalized["damage_report"] as Map,
        );

        reportMap["vehicle"] = normalizedVehicle;
        normalized["damage_report"] = reportMap;
        normalized["damageReport"] = reportMap;
      }
    }

    if (normalizedTechnician != null) {
      normalized["technician"] = normalizedTechnician;
      normalized["mechanic"] = normalizedTechnician;
      normalized["assigned_technician"] = normalizedTechnician;
      normalized["assignedTechnician"] = normalizedTechnician;
      normalized["technician_name"] ??=
          normalizedTechnician["name"] ?? normalizedTechnician["username"];
    }

    if (normalizedDriver != null) {
      normalized["driver"] = normalizedDriver;
    }

    if (normalizedMaintenance != null) {
      normalized["maintenance_result"] = normalizedMaintenance;
      normalized["technician_result"] = normalizedMaintenance;
      normalized["technician_response"] = normalizedMaintenance;
    }

    if (normalizedBooking != null) {
      final bookingMap = Map<String, dynamic>.from(normalizedBooking);

      if (normalizedVehicle != null) {
        bookingMap["vehicle"] ??= normalizedVehicle;
      }

      if (normalizedDamageReport != null) {
        bookingMap["damage_report"] ??= normalizedDamageReport;
        bookingMap["damageReport"] ??= normalizedDamageReport;
      }

      if (normalizedTechnician != null) {
        bookingMap["technician"] ??= normalizedTechnician;
      }

      if (normalizedDriver != null) {
        bookingMap["driver"] ??= normalizedDriver;
      }

      if (normalizedMaintenance != null) {
        bookingMap["maintenance_result"] ??= normalizedMaintenance;
        bookingMap["technician_result"] ??= normalizedMaintenance;
      }

      normalized["booking"] = bookingMap;
      normalized["service_booking"] = bookingMap;
      normalized["serviceBooking"] = bookingMap;
    }

    // -------------------------------------------------------------------------
    // Root summary
    // -------------------------------------------------------------------------

    final mapsByPriority = <Map<String, dynamic>>[
      if (normalizedBooking != null) normalizedBooking,
      if (normalizedMaintenance != null) normalizedMaintenance,
      normalized,
      if (normalizedVehicle != null) normalizedVehicle,
      if (normalizedDamageReport != null) normalizedDamageReport,
    ];

    _setFirst(normalized, "booking_id", mapsByPriority, [
      "booking_id",
      "service_booking_id",
      "id",
    ]);

    if (normalizedDamageReport != null) {
      _setFirst(normalized, "damage_report_id", [normalizedDamageReport, normalized], [
        "damage_report_id",
        "damage_id",
        "report_id",
        "id",
      ]);
    } else {
      _setFirst(normalized, "damage_report_id", mapsByPriority, [
        "damage_report_id",
        "damage_id",
        "report_id",
      ]);
    }

    if (normalizedVehicle != null) {
      normalized["equipment_name"] ??= normalizedVehicle["equipment_name"];
      normalized["plate_number"] ??= normalizedVehicle["plate_number"];
      normalized["serial_number"] ??= normalizedVehicle["serial_number"];
      normalized["initial_kpi"] ??= normalizedVehicle["initial_kpi"];
      normalized["initial_hour_meter"] ??=
          normalizedVehicle["initial_hour_meter"];
      normalized["target_availability"] ??=
          normalizedVehicle["target_availability"];
      normalized["target_ma"] ??= normalizedVehicle["target_ma"];
      normalized["vehicle_status"] ??= normalizedVehicle["status"];
    }

    if (normalizedDamageReport != null) {
      normalized["image"] ??= normalizedDamageReport["image"];
      normalized["image_url"] ??= normalizedDamageReport["image_url"];
      normalized["imageUrl"] ??= normalizedDamageReport["imageUrl"];
      normalized["damage_type"] ??= normalizedDamageReport["damage_type"];
      normalized["description"] ??= normalizedDamageReport["description"];
    }

    _setFirst(normalized, "status", mapsByPriority, [
      "service_booking_status",
      "booking_status",
      "status",
      "computed_status",
    ]);

    final normalizedStatus = _getNormalizedStatus(normalized);

    normalized["status"] = normalizedStatus;
    normalized["booking_status"] = normalizedStatus;
    normalized["service_booking_status"] = normalizedStatus;

    _setFirst(normalized, "priority", mapsByPriority, ["priority"]);
    _setFirst(normalized, "preferred_at", mapsByPriority, ["preferred_at"]);
    _setFirst(normalized, "requested_at", mapsByPriority, [
      "requested_at",
      "created_at",
    ]);
    _setFirst(normalized, "scheduled_at", mapsByPriority, ["scheduled_at"]);
    _setFirst(normalized, "estimated_finish_at", mapsByPriority, [
      "estimated_finish_at",
      "estimated_completed_at",
      "estimated_done_at",
    ]);
    _setFirst(normalized, "started_at", mapsByPriority, [
      "started_at",
      "service_started_at",
      "repair_started_at",
      "maintenance_started_at",
    ]);
    _setFirst(normalized, "completed_at", mapsByPriority, [
      "completed_at",
      "finished_at",
      "service_completed_at",
      "repair_completed_at",
      "maintenance_completed_at",
    ]);

    _setFirst(normalized, "note_driver", mapsByPriority, ["note_driver"]);
    _setFirst(normalized, "note_admin", mapsByPriority, ["note_admin"]);
    _setFirst(normalized, "note_technician", mapsByPriority, [
      "note_technician",
      "technician_note",
      "note_teknisi",
      "mechanic_note",
      "note",
    ]);

    // -------------------------------------------------------------------------
    // Data mentah maintenance dari teknisi
    // -------------------------------------------------------------------------

    final finalHourMeter = _firstFromMaps(mapsByPriority, [
      "final_hour_meter",
      "current_hour_meter",
      "latest_hour_meter",
      "hour_meter_terbaru",
      "vehicle_current_hour_meter",
      "vehicle_latest_hour_meter",
    ]);

    if (_hasValue(finalHourMeter)) {
      normalized["final_hour_meter"] = finalHourMeter;
      normalized["current_hour_meter"] = finalHourMeter;
      normalized["latest_hour_meter"] = finalHourMeter;
    }

    _setFirst(normalized, "total_repair_time", mapsByPriority, [
      "total_repair_time",
      "repair_time",
      "repair_time_hours",
      "total_repair_hours",
    ]);

    _setFirst(normalized, "total_operational_time", mapsByPriority, [
      "total_operational_time",
      "operational_time",
      "operational_time_hours",
      "total_operational_hours",
    ]);

    _setFirst(normalized, "failure_count", mapsByPriority, [
      "failure_count",
      "number_of_failures",
      "failures",
    ]);

    _setFirst(normalized, "actual_operating_hours", mapsByPriority, [
      "actual_operating_hours",
      "actual_operation_hours",
      "actual_operational_hours",
    ]);

    _setFirst(normalized, "breakdown_hours", mapsByPriority, [
      "breakdown_hours",
      "breakdown_time",
      "breakdown_time_hours",
    ]);

    // -------------------------------------------------------------------------
    // Hasil hitung backend
    // -------------------------------------------------------------------------

    _setFirst(normalized, "mttr", mapsByPriority, [
      "mttr",
      "mean_time_to_repair",
    ]);

    _setFirst(normalized, "mtbf", mapsByPriority, [
      "mtbf",
      "mean_time_between_failures",
    ]);

    _setFirst(normalized, "ma", mapsByPriority, [
      "ma",
      "current_ma",
      "latest_ma",
      "mechanical_availability",
      "vehicle_current_ma",
    ]);

    normalized["current_ma"] ??= normalized["ma"];
    normalized["mechanical_availability"] ??= normalized["ma"];

    // -------------------------------------------------------------------------
    // Status aman
    // -------------------------------------------------------------------------

    normalized["computed_status"] = _getNormalizedStatus(normalized);
    normalized["computed_status_label"] =
        _statusLabel(normalized["computed_status"]?.toString() ?? "menunggu");

    return normalized;
  }

  static Map<String, dynamic>? _extractDamageReport(
    Map<String, dynamic> item,
  ) {
    for (final key in [
      "damage_report",
      "damageReport",
      "report",
    ]) {
      final map = _asMap(item[key]);
      if (map != null) return map;
    }

    final hasDirectReportFields = item["damage_type"] != null ||
        item["description"] != null ||
        item["image"] != null ||
        item["image_url"] != null ||
        item["computed_status"] != null;

    if (hasDirectReportFields) {
      return item;
    }

    return null;
  }

  static Map<String, dynamic>? _extractBooking(
    Map<String, dynamic> item,
  ) {
    for (final key in [
      "service_booking",
      "serviceBooking",
      "latest_service_booking",
      "latestServiceBooking",
      "booking",
    ]) {
      final map = _asMap(item[key]);
      if (map != null) return map;
    }

    final hasBookingFields = item["scheduled_at"] != null ||
        item["preferred_at"] != null ||
        item["estimated_finish_at"] != null ||
        item["requested_at"] != null ||
        item["started_at"] != null ||
        item["completed_at"] != null ||
        item["note_driver"] != null ||
        item["note_admin"] != null ||
        item["note_technician"] != null ||
        item["mttr"] != null ||
        item["mtbf"] != null ||
        item["ma"] != null ||
        item["final_hour_meter"] != null ||
        item["current_hour_meter"] != null ||
        item["total_repair_time"] != null ||
        item["breakdown_hours"] != null ||
        item["damage_report_id"] != null ||
        item["vehicle_id"] != null;

    if (hasBookingFields) {
      return item;
    }

    return null;
  }

  static Map<String, dynamic>? _extractMaintenanceResult(
    Map<String, dynamic> item,
    Map<String, dynamic>? damageReport,
    Map<String, dynamic>? booking,
  ) {
    for (final source in [item, booking, damageReport]) {
      if (source == null) continue;

      for (final key in [
        "maintenance_result",
        "maintenanceResult",
        "technician_result",
        "technicianResult",
        "technician_response",
        "technicianResponse",
        "latest_technician_response",
        "latestTechnicianResponse",
        "latest_response",
        "latestResponse",
        "response",
      ]) {
        final map = _asMap(source[key]);
        if (map != null) return map;
      }
    }

    final hasMaintenanceFields = item["note_technician"] != null ||
        item["final_hour_meter"] != null ||
        item["total_repair_time"] != null ||
        item["actual_operating_hours"] != null ||
        item["breakdown_hours"] != null ||
        item["mttr"] != null ||
        item["mtbf"] != null ||
        item["ma"] != null;

    if (hasMaintenanceFields) {
      return item;
    }

    return null;
  }

  static Map<String, dynamic>? _extractVehicle(
    Map<String, dynamic> item,
    Map<String, dynamic>? damageReport,
    Map<String, dynamic>? booking,
  ) {
    for (final source in [item, booking, damageReport]) {
      if (source == null) continue;

      final map = _asMap(source["vehicle"]);
      if (map != null) return map;
    }

    final hasVehicleFields = item["equipment_name"] != null ||
        item["plate_number"] != null ||
        item["serial_number"] != null ||
        item["initial_kpi"] != null ||
        item["initial_hour_meter"] != null ||
        item["current_hour_meter"] != null ||
        item["latest_hour_meter"] != null ||
        item["final_hour_meter"] != null;

    if (hasVehicleFields) {
      return item;
    }

    final hasReportVehicleAlias = damageReport?["vehicle_equipment_name"] != null ||
        damageReport?["vehicle_plate_number"] != null ||
        damageReport?["vehicle_serial_number"] != null ||
        damageReport?["vehicle_initial_kpi"] != null ||
        damageReport?["vehicle_initial_hour_meter"] != null ||
        damageReport?["vehicle_current_hour_meter"] != null;

    if (hasReportVehicleAlias && damageReport != null) {
      return {
        "id": damageReport["vehicle_id"],
        "equipment_name": damageReport["vehicle_equipment_name"],
        "plate_number": damageReport["vehicle_plate_number"],
        "serial_number": damageReport["vehicle_serial_number"],
        "initial_kpi": damageReport["vehicle_initial_kpi"],
        "initial_hour_meter": damageReport["vehicle_initial_hour_meter"],
        "current_hour_meter": damageReport["vehicle_current_hour_meter"],
        "latest_hour_meter": damageReport["vehicle_latest_hour_meter"] ??
            damageReport["vehicle_current_hour_meter"],
        "target_availability": damageReport["vehicle_target_availability"],
        "target_ma": damageReport["vehicle_target_ma"],
        "current_ma": damageReport["vehicle_current_ma"],
        "status": damageReport["vehicle_status"],
      };
    }

    return null;
  }

  static Map<String, dynamic>? _extractTechnician(
    Map<String, dynamic> item,
    Map<String, dynamic>? booking,
    Map<String, dynamic>? maintenance,
  ) {
    for (final source in [item, booking, maintenance]) {
      if (source == null) continue;

      for (final key in [
        "technician",
        "mechanic",
        "assigned_technician",
        "assignedTechnician",
      ]) {
        final map = _asMap(source[key]);
        if (map != null) return map;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _extractDriver(
    Map<String, dynamic> item,
    Map<String, dynamic>? damageReport,
    Map<String, dynamic>? booking,
  ) {
    for (final source in [item, booking, damageReport]) {
      if (source == null) continue;

      final map = _asMap(source["driver"]);
      if (map != null) return map;
    }

    return null;
  }

  static Map<String, dynamic> _normalizeDamageReport(
    Map<String, dynamic> damageReport,
  ) {
    final report = Map<String, dynamic>.from(damageReport);

    final imageRaw = report["image_url"] ?? report["imageUrl"] ?? report["image"];
    final imageUrl = _resolveImageUrl(imageRaw);

    if (imageUrl != null) {
      report["image_url"] = imageUrl;
      report["imageUrl"] = imageUrl;
    }

    final vehicle = _extractVehicle(report, report, null);

    if (vehicle != null) {
      final normalizedVehicle = _normalizeVehicle(vehicle);

      report["vehicle"] = normalizedVehicle;
      report["vehicle_equipment_name"] ??= normalizedVehicle["equipment_name"];
      report["vehicle_plate_number"] ??= normalizedVehicle["plate_number"];
      report["vehicle_serial_number"] ??= normalizedVehicle["serial_number"];
      report["vehicle_initial_kpi"] ??= normalizedVehicle["initial_kpi"];
      report["vehicle_initial_hour_meter"] ??=
          normalizedVehicle["initial_hour_meter"];
      report["vehicle_current_hour_meter"] ??=
          normalizedVehicle["current_hour_meter"];
      report["vehicle_latest_hour_meter"] ??=
          normalizedVehicle["latest_hour_meter"];
      report["vehicle_target_availability"] ??=
          normalizedVehicle["target_availability"];
      report["vehicle_current_ma"] ??= normalizedVehicle["current_ma"];
      report["vehicle_status"] ??= normalizedVehicle["status"];
    }

    report["computed_status"] ??= report["status"] ?? "menunggu";
    report["computed_status_label"] ??=
        _statusLabel(report["computed_status"]?.toString() ?? "menunggu");

    return report;
  }

  static Map<String, dynamic> _normalizeBooking(
    Map<String, dynamic> booking,
    Map<String, dynamic>? vehicle,
    Map<String, dynamic>? maintenance,
    Map<String, dynamic>? damageReport,
  ) {
    final normalized = Map<String, dynamic>.from(booking);

    final mapsByPriority = <Map<String, dynamic>>[
      normalized,
      if (maintenance != null) maintenance,
      if (vehicle != null) vehicle,
      if (damageReport != null) damageReport,
    ];

    normalized["booking_id"] ??= normalized["id"];
    normalized["service_booking_id"] ??= normalized["booking_id"];

    _setFirst(normalized, "started_at", mapsByPriority, [
      "started_at",
      "service_started_at",
      "repair_started_at",
    ]);

    _setFirst(normalized, "completed_at", mapsByPriority, [
      "completed_at",
      "finished_at",
      "service_completed_at",
      "repair_completed_at",
    ]);

    _setFirst(normalized, "note_technician", mapsByPriority, [
      "note_technician",
      "technician_note",
      "note_teknisi",
      "mechanic_note",
      "note",
    ]);

    final finalHourMeter = _firstFromMaps(mapsByPriority, [
      "final_hour_meter",
      "current_hour_meter",
      "latest_hour_meter",
      "hour_meter_terbaru",
      "vehicle_current_hour_meter",
      "vehicle_latest_hour_meter",
    ]);

    if (_hasValue(finalHourMeter)) {
      normalized["final_hour_meter"] = finalHourMeter;
      normalized["current_hour_meter"] = finalHourMeter;
      normalized["latest_hour_meter"] = finalHourMeter;
    }

    _setFirst(normalized, "total_repair_time", mapsByPriority, [
      "total_repair_time",
      "repair_time",
      "repair_time_hours",
      "total_repair_hours",
    ]);

    _setFirst(normalized, "total_operational_time", mapsByPriority, [
      "total_operational_time",
      "operational_time",
      "operational_time_hours",
      "total_operational_hours",
    ]);

    _setFirst(normalized, "failure_count", mapsByPriority, [
      "failure_count",
      "number_of_failures",
      "failures",
    ]);

    _setFirst(normalized, "actual_operating_hours", mapsByPriority, [
      "actual_operating_hours",
      "actual_operation_hours",
      "actual_operational_hours",
    ]);

    _setFirst(normalized, "breakdown_hours", mapsByPriority, [
      "breakdown_hours",
      "breakdown_time",
      "breakdown_time_hours",
    ]);

    _setFirst(normalized, "mttr", mapsByPriority, [
      "mttr",
      "mean_time_to_repair",
    ]);

    _setFirst(normalized, "mtbf", mapsByPriority, [
      "mtbf",
      "mean_time_between_failures",
    ]);

    _setFirst(normalized, "ma", mapsByPriority, [
      "ma",
      "current_ma",
      "latest_ma",
      "mechanical_availability",
      "vehicle_current_ma",
    ]);

    normalized["current_ma"] ??= normalized["ma"];
    normalized["mechanical_availability"] ??= normalized["ma"];

    final normalizedStatus = _getNormalizedStatus(normalized);

    normalized["status"] = normalizedStatus;
    normalized["booking_status"] = normalizedStatus;
    normalized["service_booking_status"] = normalizedStatus;

    return normalized;
  }

  static Map<String, dynamic> _normalizeMaintenanceResult(
    Map<String, dynamic> result,
  ) {
    final normalized = Map<String, dynamic>.from(result);

    normalized["note_technician"] ??=
        normalized["technician_note"] ??
        normalized["note_teknisi"] ??
        normalized["mechanic_note"] ??
        normalized["note"];

    normalized["final_hour_meter"] ??=
        normalized["current_hour_meter"] ?? normalized["latest_hour_meter"];

    normalized["current_hour_meter"] ??= normalized["final_hour_meter"];
    normalized["latest_hour_meter"] ??= normalized["final_hour_meter"];

    normalized["total_repair_time"] ??=
        normalized["repair_time"] ?? normalized["repair_time_hours"];

    normalized["total_operational_time"] ??=
        normalized["operational_time"] ?? normalized["operational_time_hours"];

    normalized["failure_count"] ??=
        normalized["number_of_failures"] ?? normalized["failures"];

    normalized["actual_operating_hours"] ??=
        normalized["actual_operation_hours"];

    normalized["breakdown_hours"] ??= normalized["breakdown_time"];

    normalized["mttr"] ??= normalized["mean_time_to_repair"];
    normalized["mtbf"] ??= normalized["mean_time_between_failures"];
    normalized["ma"] ??=
        normalized["current_ma"] ?? normalized["mechanical_availability"];

    return normalized;
  }

  static Map<String, dynamic> _normalizeVehicle(
    Map<String, dynamic> vehicle,
  ) {
    final normalized = Map<String, dynamic>.from(vehicle);

    final initialValue = _firstFromMaps([normalized], [
          "initial_hour_meter",
          "initial_kpi",
          "hour_meter_awal",
          "kpi_awal",
        ]) ??
        0;

    normalized["initial_kpi"] ??= initialValue;
    normalized["initial_hour_meter"] ??= initialValue;

    final currentValue = _firstFromMaps([normalized], [
          "current_hour_meter",
          "latest_hour_meter",
          "final_hour_meter",
          "hour_meter_terbaru",
        ]) ??
        initialValue;

    normalized["current_hour_meter"] ??= currentValue;
    normalized["latest_hour_meter"] ??= currentValue;
    normalized["final_hour_meter"] ??= currentValue;

    normalized["target_availability"] ??= normalized["target_ma"] ?? 90;
    normalized["target_ma"] ??= normalized["target_availability"] ?? 90;

    normalized["current_ma"] ??=
        normalized["ma"] ?? normalized["mechanical_availability"];
    normalized["ma"] ??= normalized["current_ma"];
    normalized["mechanical_availability"] ??= normalized["current_ma"];

    normalized["status"] ??= normalized["unit_status"] ?? "active";
    normalized["unit_status"] ??= normalized["status"] ?? "active";

    return normalized;
  }

  static String? _resolveImageUrl(dynamic value) {
    final raw = value?.toString();

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

  static String _normalizeStatusValue(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? "";

    if (raw.isEmpty || raw == "null" || raw == "-") {
      return "menunggu";
    }

    final status = raw.replaceAll(" ", "_").replaceAll("-", "_");

    switch (status) {
      case "pending":
      case "waiting":
      case "reported":
      case "menunggu":
        return "requested";
      case "scheduled":
      case "terjadwal":
        return "approved";
      case "ongoing":
      case "proses":
      case "diproses":
        return "in_progress";
      case "finished":
      case "selesai":
      case "done":
      case "closed":
        return "completed";
      case "reject":
      case "ditolak":
        return "rejected";
      case "cancelled":
      case "dibatalkan":
        return "canceled";
      default:
        return status;
    }
  }

  static String _getNormalizedStatus(Map<String, dynamic> item) {
    final damageReport = _extractDamageReport(item);
    final booking = _extractBooking(item);

    final rawStatus = booking?["service_booking_status"] ??
        booking?["booking_status"] ??
        booking?["status"] ??
        item["service_booking_status"] ??
        item["booking_status"] ??
        damageReport?["service_booking_status"] ??
        damageReport?["booking_status"] ??
        damageReport?["computed_status"] ??
        damageReport?["status"] ??
        item["computed_status"] ??
        item["status"] ??
        "menunggu";

    return _normalizeStatusValue(rawStatus);
  }

  static String _statusLabel(String status) {
    switch (_normalizeStatusValue(status)) {
      case "menunggu":
      case "reported":
      case "pending":
      case "requested":
        return "Reported";

      case "approved":
      case "scheduled":
        return "Scheduled";

      case "rescheduled":
        return "Rescheduled";

      case "proses":
      case "in_progress":
      case "ongoing":
        return "In Progress";

      case "butuh_followup_admin":
      case "waiting_parts":
      case "on_hold":
        return "Waiting Parts";

      case "approved_followup_admin":
        return "Follow-up Approved";

      case "selesai":
      case "finished":
      case "completed":
        return "Completed";

      case "rejected":
      case "ditolak":
        return "Rejected";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "fatal":
        return "Fatal";

      default:
        return status.isEmpty ? "Reported" : status;
    }
  }

  // ---------------------------------------------------------------------------
  // GENERIC MAP HELPER
  // ---------------------------------------------------------------------------

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static bool _hasValue(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    return text.isNotEmpty && text != "null" && text != "-";
  }

  static dynamic _firstFromMaps(
    List<Map<String, dynamic>> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      for (final key in keys) {
        if (!map.containsKey(key)) continue;

        final value = map[key];

        if (_hasValue(value)) {
          return value;
        }
      }
    }

    return null;
  }

  static void _setFirst(
    Map<String, dynamic> target,
    String targetKey,
    List<Map<String, dynamic>> maps,
    List<String> sourceKeys,
  ) {
    final value = _firstFromMaps(maps, sourceKeys);

    if (_hasValue(value)) {
      target[targetKey] = value;
    }
  }

  // ---------------------------------------------------------------------------
  // JSON HELPER
  // ---------------------------------------------------------------------------

  static dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded["data"];

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic>) {
        final paginatedData = data["data"];

        if (paginatedData is List) {
          return paginatedData;
        }

        for (final key in [
          "bookings",
          "service_bookings",
          "reports",
          "damage_reports",
          "items",
          "results",
        ]) {
          final nestedList = data[key];
          if (nestedList is List) {
            return nestedList;
          }
        }
      }

      for (final key in [
        "bookings",
        "service_bookings",
        "reports",
        "damage_reports",
        "items",
        "results",
      ]) {
        final nestedList = decoded[key];
        if (nestedList is List) {
          return nestedList;
        }
      }
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);
      return _extractList(mapped);
    }

    return [];
  }

  static String _extractErrorMessage(dynamic decoded, String fallbackBody) {
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

        if (firstValue != null) {
          return firstValue.toString();
        }
      }
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);

      final message = mapped["message"]?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errors = mapped["errors"];

      if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;

        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }

        if (firstValue != null) {
          return firstValue.toString();
        }
      }
    }

    if (fallbackBody.trim().isNotEmpty) {
      return "Gagal mengambil repair status: $fallbackBody";
    }

    return "Gagal mengambil repair status.";
  }
}
