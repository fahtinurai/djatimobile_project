import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';
import 'package:djatimobile_project/core/services/api_service.dart';

class TechnicianDamageReportService {
  static String get baseUrl => ApiService.baseUrl;

  // ---------------------------------------------------------------------------
  // HEADERS & PARSER
  // ---------------------------------------------------------------------------

  static Future<Map<String, String>> _headers({
    bool isForm = false,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    return {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
      if (isForm) "Content-Type": "application/x-www-form-urlencoded",
    };
  }

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

  static Map<String, dynamic> _successFallback({
    String message = "Request berhasil",
    dynamic data,
    String? rawBody,
  }) {
    return {
      "success": true,
      "message": message,
      "data": data,
      if (rawBody != null) "raw_body": rawBody,
    };
  }

  static List<dynamic> _parseList(String body) {
    final decoded = _safeJsonDecode(body);

    if (decoded == null) {
      return [];
    }

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

        final jobsFromData = data["jobs"];
        if (jobsFromData is List) {
          return jobsFromData;
        }

        final serviceJobsFromData = data["service_jobs"];
        if (serviceJobsFromData is List) {
          return serviceJobsFromData;
        }

        final bookingsFromData = data["bookings"];
        if (bookingsFromData is List) {
          return bookingsFromData;
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

        final nestedJobs = data["jobs"];
        if (nestedJobs is List) {
          return nestedJobs;
        }

        final nestedServiceJobs = data["service_jobs"];
        if (nestedServiceJobs is List) {
          return nestedServiceJobs;
        }

        final nestedBookings = data["bookings"];
        if (nestedBookings is List) {
          return nestedBookings;
        }
      }
    }

    return [];
  }

  static Map<String, dynamic> _parseMap(
    String body, {
    String fallbackMessage = "Request berhasil",
  }) {
    final decoded = _safeJsonDecode(body);

    if (decoded == null) {
      return _successFallback(
        message: fallbackMessage,
        data: null,
        rawBody: body.trim().isNotEmpty ? body : null,
      );
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded["data"];

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      final booking = decoded["booking"];
      if (booking is Map<String, dynamic>) {
        return booking;
      }

      if (booking is Map) {
        return Map<String, dynamic>.from(booking);
      }

      final job = decoded["job"];
      if (job is Map<String, dynamic>) {
        return job;
      }

      if (job is Map) {
        return Map<String, dynamic>.from(job);
      }

      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return _successFallback(
      message: fallbackMessage,
      data: decoded,
    );
  }

  static String _errorMessage(http.Response response, String fallback) {
    if (response.body.trim().isEmpty) {
      return "$fallback. Status: ${response.statusCode}";
    }

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

    return "$fallback: ${response.body}";
  }

  static bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  // ---------------------------------------------------------------------------
  // NORMALIZER SERVICE JOB
  // ---------------------------------------------------------------------------

  static List<dynamic> _normalizeServiceJobList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizeServiceJob(item);
      }

      if (item is Map) {
        return _normalizeServiceJob(Map<String, dynamic>.from(item));
      }

      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizeServiceJob(
    Map<String, dynamic> item,
  ) {
    final job = Map<String, dynamic>.from(item);

    final damageReport = _extractDamageReport(job);
    final vehicle = _extractVehicle(job, damageReport);

    if (damageReport != null) {
      final normalizedReport = Map<String, dynamic>.from(damageReport);

      if (vehicle != null) {
        normalizedReport["vehicle"] = _normalizeVehicle(vehicle);
      }

      job["damage_report"] = normalizedReport;
      job["damageReport"] ??= normalizedReport;
    }

    if (vehicle != null) {
      final normalizedVehicle = _normalizeVehicle(vehicle);

      job["vehicle"] = normalizedVehicle;

      job["equipment_name"] ??= normalizedVehicle["equipment_name"];
      job["plate_number"] ??= normalizedVehicle["plate_number"];
      job["serial_number"] ??= normalizedVehicle["serial_number"];

      job["initial_hour_meter"] ??=
          normalizedVehicle["initial_hour_meter"] ??
          normalizedVehicle["initial_kpi"];

      job["initial_kpi"] ??=
          normalizedVehicle["initial_kpi"] ??
          normalizedVehicle["initial_hour_meter"];

      job["current_hour_meter"] ??=
          normalizedVehicle["current_hour_meter"] ??
          normalizedVehicle["latest_hour_meter"] ??
          normalizedVehicle["final_hour_meter"] ??
          normalizedVehicle["initial_hour_meter"] ??
          normalizedVehicle["initial_kpi"];

      job["latest_hour_meter"] ??=
          job["current_hour_meter"];

      job["target_availability"] ??=
          normalizedVehicle["target_availability"] ??
          normalizedVehicle["target_ma"] ??
          90;

      job["current_ma"] ??=
          normalizedVehicle["current_ma"] ??
          normalizedVehicle["ma"] ??
          normalizedVehicle["mechanical_availability"];

      job["vehicle_status"] ??=
          normalizedVehicle["status"] ??
          normalizedVehicle["unit_status"] ??
          "active";
    }

    /*
    |--------------------------------------------------------------------------
    | Alias data mentah maintenance
    |--------------------------------------------------------------------------
    |
    | Tujuannya supaya mechanic_flow.dart dan mechanic_history_page.dart
    | tetap bisa membaca field walaupun backend memakai penamaan berbeda.
    |
    */
    job["final_hour_meter"] ??=
        job["current_hour_meter"] ??
        job["latest_hour_meter"];

    job["total_repair_time"] ??=
        job["repair_time"] ??
        job["repair_time_hours"];

    job["total_operational_time"] ??=
        job["operational_time"] ??
        job["operational_time_hours"];

    job["failure_count"] ??=
        job["number_of_failures"] ??
        job["failures"];

    job["actual_operating_hours"] ??=
        job["actual_operation_hours"];

    job["breakdown_hours"] ??=
        job["breakdown_time"];

    return job;
  }

  static Map<String, dynamic>? _extractDamageReport(
    Map<String, dynamic> job,
  ) {
    final snake = job["damage_report"];
    if (snake is Map<String, dynamic>) return snake;
    if (snake is Map) return Map<String, dynamic>.from(snake);

    final camel = job["damageReport"];
    if (camel is Map<String, dynamic>) return camel;
    if (camel is Map) return Map<String, dynamic>.from(camel);

    final report = job["report"];
    if (report is Map<String, dynamic>) return report;
    if (report is Map) return Map<String, dynamic>.from(report);

    final hasDirectReportFields =
        job["damage_report_id"] != null ||
        job["damage_type"] != null ||
        job["description"] != null ||
        job["image"] != null ||
        job["image_url"] != null;

    if (hasDirectReportFields) {
      return job;
    }

    return null;
  }

  static Map<String, dynamic>? _extractVehicle(
    Map<String, dynamic> job,
    Map<String, dynamic>? damageReport,
  ) {
    final directVehicle = job["vehicle"];
    if (directVehicle is Map<String, dynamic>) return directVehicle;
    if (directVehicle is Map) return Map<String, dynamic>.from(directVehicle);

    final reportVehicle = damageReport?["vehicle"];
    if (reportVehicle is Map<String, dynamic>) return reportVehicle;
    if (reportVehicle is Map) {
      return Map<String, dynamic>.from(reportVehicle);
    }

    final hasVehicleFields =
        job["equipment_name"] != null ||
        job["plate_number"] != null ||
        job["serial_number"] != null ||
        job["initial_hour_meter"] != null ||
        job["initial_kpi"] != null ||
        job["current_hour_meter"] != null ||
        job["latest_hour_meter"] != null;

    if (hasVehicleFields) {
      return job;
    }

    final hasReportVehicleAliases =
        damageReport?["vehicle_equipment_name"] != null ||
        damageReport?["vehicle_plate_number"] != null ||
        damageReport?["vehicle_serial_number"] != null ||
        damageReport?["vehicle_initial_hour_meter"] != null ||
        damageReport?["vehicle_initial_kpi"] != null ||
        damageReport?["vehicle_current_hour_meter"] != null;

    if (hasReportVehicleAliases && damageReport != null) {
      return {
        "id": damageReport["vehicle_id"],
        "equipment_name": damageReport["vehicle_equipment_name"],
        "plate_number": damageReport["vehicle_plate_number"],
        "serial_number": damageReport["vehicle_serial_number"],
        "initial_hour_meter": damageReport["vehicle_initial_hour_meter"],
        "initial_kpi": damageReport["vehicle_initial_kpi"],
        "current_hour_meter": damageReport["vehicle_current_hour_meter"],
        "target_availability": damageReport["vehicle_target_availability"],
        "status": damageReport["vehicle_status"],
      };
    }

    return null;
  }

  static Map<String, dynamic> _normalizeVehicle(
    Map<String, dynamic> vehicle,
  ) {
    final normalized = Map<String, dynamic>.from(vehicle);

    final initialValue =
        normalized["initial_hour_meter"] ??
        normalized["initial_kpi"] ??
        normalized["hour_meter_awal"] ??
        normalized["kpi_awal"] ??
        0;

    normalized["initial_hour_meter"] ??= initialValue;
    normalized["initial_kpi"] ??= initialValue;

    final currentValue =
        normalized["current_hour_meter"] ??
        normalized["latest_hour_meter"] ??
        normalized["final_hour_meter"] ??
        normalized["hour_meter_terbaru"] ??
        normalized["initial_hour_meter"] ??
        normalized["initial_kpi"] ??
        0;

    normalized["current_hour_meter"] ??= currentValue;
    normalized["latest_hour_meter"] ??= currentValue;
    normalized["final_hour_meter"] ??= currentValue;

    normalized["target_availability"] ??=
        normalized["target_ma"] ?? 90;

    normalized["target_ma"] ??=
        normalized["target_availability"] ?? 90;

    normalized["current_ma"] ??=
        normalized["ma"] ??
        normalized["mechanical_availability"];

    normalized["status"] ??=
        normalized["unit_status"] ?? "active";

    normalized["unit_status"] ??=
        normalized["status"] ?? "active";

    return normalized;
  }

  // ---------------------------------------------------------------------------
  // BODY BUILDER
  // ---------------------------------------------------------------------------

  static void _putStringIfFilled(
    Map<String, String> body,
    String key,
    String? value,
  ) {
    final cleanValue = value?.trim();

    if (cleanValue != null && cleanValue.isNotEmpty) {
      body[key] = cleanValue;
    }
  }

  static void _putDoubleIfNotNull(
    Map<String, String> body,
    String key,
    double? value, {
    int fractionDigits = 2,
  }) {
    if (value != null) {
      body[key] = value.toStringAsFixed(fractionDigits);
    }
  }

  static void _putIntIfNotNull(
    Map<String, String> body,
    String key,
    int? value,
  ) {
    if (value != null) {
      body[key] = value.toString();
    }
  }

  static Map<String, String> _buildCompleteBody({
    String? noteTechnician,

    /*
    |--------------------------------------------------------------------------
    | Field baru sesuai flow yang kamu mau
    |--------------------------------------------------------------------------
    |
    | Flutter mengirim data mentah.
    | Backend menghitung nilai resmi:
    | - MTTR
    | - MTBF
    | - MA
    |
    | Backend juga sebaiknya update:
    | - vehicles.current_hour_meter
    | - vehicles.current_ma
    | - service_bookings.total_repair_time, dll
    |
    */
    double? finalHourMeter,
    double? totalRepairTime,
    double? totalOperationalTime,
    int? failureCount,
    double? actualOperatingHours,
    double? breakdownHours,

    /*
    |--------------------------------------------------------------------------
    | Field lama untuk kompatibilitas page lama
    |--------------------------------------------------------------------------
    |
    | Nilai ini tidak disarankan menjadi nilai resmi dari Flutter.
    | Nilai resmi tetap sebaiknya dihitung backend.
    |
    */
    double? mttr,
    double? mtbf,
    double? ma,
  }) {
    final body = <String, String>{};

    _putStringIfFilled(body, "note_technician", noteTechnician);

    /*
    |--------------------------------------------------------------------------
    | Hour meter terbaru setelah perbaikan
    |--------------------------------------------------------------------------
    |
    | Jangan update initial_hour_meter.
    | Gunakan final/current/latest hour meter untuk kondisi terbaru.
    |
    */
    _putDoubleIfNotNull(body, "final_hour_meter", finalHourMeter);
    _putDoubleIfNotNull(body, "current_hour_meter", finalHourMeter);
    _putDoubleIfNotNull(body, "latest_hour_meter", finalHourMeter);

    /*
    |--------------------------------------------------------------------------
    | Data mentah maintenance untuk backend
    |--------------------------------------------------------------------------
    */
    _putDoubleIfNotNull(body, "total_repair_time", totalRepairTime);
    _putDoubleIfNotNull(body, "repair_time", totalRepairTime);
    _putDoubleIfNotNull(body, "repair_time_hours", totalRepairTime);

    _putDoubleIfNotNull(body, "total_operational_time", totalOperationalTime);
    _putDoubleIfNotNull(body, "operational_time", totalOperationalTime);
    _putDoubleIfNotNull(body, "operational_time_hours", totalOperationalTime);

    _putIntIfNotNull(body, "failure_count", failureCount);
    _putIntIfNotNull(body, "number_of_failures", failureCount);
    _putIntIfNotNull(body, "failures", failureCount);

    _putDoubleIfNotNull(body, "actual_operating_hours", actualOperatingHours);
    _putDoubleIfNotNull(body, "actual_operation_hours", actualOperatingHours);

    _putDoubleIfNotNull(body, "breakdown_hours", breakdownHours);
    _putDoubleIfNotNull(body, "breakdown_time", breakdownHours);

    /*
    |--------------------------------------------------------------------------
    | Legacy compatibility
    |--------------------------------------------------------------------------
    |
    | Tetap dikirim jika ada page lama yang masih memakai mttr/mtbf/ma.
    | Untuk flow baru, mechanic_flow.dart dan mechanic_history_page.dart
    | sebaiknya mengirim data mentah saja.
    |
    */
    _putDoubleIfNotNull(body, "mttr", mttr);
    _putDoubleIfNotNull(body, "mtbf", mtbf);
    _putDoubleIfNotNull(body, "ma", ma, fractionDigits: 1);

    return body;
  }

  // ---------------------------------------------------------------------------
  // MAINTENANCE SCHEDULING SERVICE JOBS
  // ---------------------------------------------------------------------------

  /// Mengambil job teknisi dari service_bookings.
  ///
  /// Backend:
  /// GET /api/technician/service-jobs?status=active
  ///
  /// Status yang disarankan:
  /// - queue  : approved, rescheduled
  /// - active : approved, rescheduled, in_progress
  /// - all    : semua
  /// - completed / canceled / dll: filter status spesifik
  static Future<List<dynamic>> getServiceJobs({
    String status = "active",
  }) async {
    final uri = Uri.parse("$baseUrl/technician/service-jobs").replace(
      queryParameters: {
        "status": status,
      },
    );

    debugPrint("GET TECHNICIAN SERVICE JOBS URL: $uri");

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    debugPrint("TECHNICIAN SERVICE JOBS STATUS: ${response.statusCode}");
    debugPrint("TECHNICIAN SERVICE JOBS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final list = _parseList(response.body);

      return _normalizeServiceJobList(list);
    }

    throw Exception(
      _errorMessage(response, "Gagal mengambil service job teknisi"),
    );
  }

  /// Detail service job berdasarkan booking ID.
  ///
  /// Backend:
  /// GET /api/technician/service-jobs/{booking}
  static Future<Map<String, dynamic>?> getServiceJobDetail({
    required int bookingId,
  }) async {
    if (bookingId <= 0) {
      throw Exception("ID booking tidak valid.");
    }

    final uri = Uri.parse("$baseUrl/technician/service-jobs/$bookingId");

    debugPrint("GET TECHNICIAN SERVICE JOB DETAIL URL: $uri");

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    debugPrint("TECHNICIAN SERVICE JOB DETAIL STATUS: ${response.statusCode}");
    debugPrint("TECHNICIAN SERVICE JOB DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      final data = _parseMap(
        response.body,
        fallbackMessage: "Detail service job berhasil diambil",
      );

      return _normalizeServiceJob(data);
    }

    throw Exception(
      _errorMessage(response, "Gagal mengambil detail service job teknisi"),
    );
  }

  /// Teknisi mulai job.
  ///
  /// Backend:
  /// POST /api/technician/service-jobs/{booking}/start
  ///
  /// Efek backend:
  /// - status -> in_progress
  /// - started_at -> now()
  /// - FCM ke driver: servis dimulai
  static Future<Map<String, dynamic>?> startServiceJob({
    required int bookingId,
    String? noteTechnician,
  }) async {
    if (bookingId <= 0) {
      throw Exception("ID booking tidak valid.");
    }

    final uri = Uri.parse("$baseUrl/technician/service-jobs/$bookingId/start");

    final body = <String, String>{};

    _putStringIfFilled(body, "note_technician", noteTechnician);

    debugPrint("POST START SERVICE JOB URL: $uri");
    debugPrint("POST START SERVICE JOB BODY: $body");

    final response = await http.post(
      uri,
      headers: await _headers(isForm: true),
      body: body,
    );

    debugPrint("START SERVICE JOB STATUS: ${response.statusCode}");
    debugPrint("START SERVICE JOB BODY: ${response.body}");

    if (_isSuccess(response.statusCode)) {
      final data = _parseMap(
        response.body,
        fallbackMessage: "Service job berhasil dimulai",
      );

      return _normalizeServiceJob(data);
    }

    throw Exception(
      _errorMessage(response, "Gagal memulai service job"),
    );
  }

  /// Teknisi menyelesaikan job.
  ///
  /// Backend:
  /// POST /api/technician/service-jobs/{booking}/complete
  ///
  /// Flow baru:
  /// - Flutter mengirim data mentah.
  /// - Backend menghitung MTTR, MTBF, dan MA.
  /// - Backend update current_hour_meter / current_ma kendaraan.
  ///
  /// Field penting:
  /// - finalHourMeter         -> hour meter terbaru setelah perbaikan
  /// - totalRepairTime        -> total waktu repair
  /// - totalOperationalTime   -> total waktu operasi
  /// - failureCount           -> jumlah failure
  /// - actualOperatingHours   -> jam operasi aktual
  /// - breakdownHours         -> jam breakdown
  static Future<Map<String, dynamic>?> completeServiceJob({
    required int bookingId,
    String? noteTechnician,

    // Field baru yang disarankan.
    double? finalHourMeter,
    double? totalRepairTime,
    double? totalOperationalTime,
    int? failureCount,
    double? actualOperatingHours,
    double? breakdownHours,

    // Field lama untuk kompatibilitas.
    double? mttr,
    double? mtbf,
    double? ma,
  }) async {
    if (bookingId <= 0) {
      throw Exception("ID booking tidak valid.");
    }

    final uri = Uri.parse(
      "$baseUrl/technician/service-jobs/$bookingId/complete",
    );

    final body = _buildCompleteBody(
      noteTechnician: noteTechnician,
      finalHourMeter: finalHourMeter,
      totalRepairTime: totalRepairTime,
      totalOperationalTime: totalOperationalTime,
      failureCount: failureCount,
      actualOperatingHours: actualOperatingHours,
      breakdownHours: breakdownHours,
      mttr: mttr,
      mtbf: mtbf,
      ma: ma,
    );

    debugPrint("POST COMPLETE SERVICE JOB URL: $uri");
    debugPrint("POST COMPLETE SERVICE JOB BODY: $body");

    final response = await http.post(
      uri,
      headers: await _headers(isForm: true),
      body: body,
    );

    debugPrint("COMPLETE SERVICE JOB STATUS: ${response.statusCode}");
    debugPrint("COMPLETE SERVICE JOB BODY: ${response.body}");

    if (_isSuccess(response.statusCode)) {
      final data = _parseMap(
        response.body,
        fallbackMessage: "Service job berhasil diselesaikan",
      );

      return _normalizeServiceJob(data);
    }

    throw Exception(
      _errorMessage(response, "Gagal menyelesaikan service job"),
    );
  }

  /// Update data maintenance untuk job yang sudah completed.
  ///
  /// Catatan:
  /// Secara route tetap memakai endpoint complete agar kompatibel dengan
  /// backend yang sudah ada. Backend sebaiknya mengizinkan update data
  /// maintenance pada status completed tanpa mengubah alur status.
  static Future<Map<String, dynamic>?> updateCompletedMaintenanceData({
    required int bookingId,
    String? noteTechnician,
    double? finalHourMeter,
    double? totalRepairTime,
    double? totalOperationalTime,
    int? failureCount,
    double? actualOperatingHours,
    double? breakdownHours,
  }) async {
    return completeServiceJob(
      bookingId: bookingId,
      noteTechnician: noteTechnician,
      finalHourMeter: finalHourMeter,
      totalRepairTime: totalRepairTime,
      totalOperationalTime: totalOperationalTime,
      failureCount: failureCount,
      actualOperatingHours: actualOperatingHours,
      breakdownHours: breakdownHours,
    );
  }

  // ---------------------------------------------------------------------------
  // COMPATIBILITY METHODS UNTUK PAGE LAMA
  // ---------------------------------------------------------------------------

  /// Kompatibilitas nama lama.
  ///
  /// Dulu:
  /// GET /technician/damage-reports
  ///
  /// Sekarang dialihkan ke:
  /// GET /technician/service-jobs
  ///
  /// includeDone = false -> active
  /// includeDone = true  -> all
  static Future<List<dynamic>> getDamageReports({
    bool includeDone = false,
    String? status,
  }) async {
    final mappedStatus = _mapLegacyStatusToServiceJobStatus(
      includeDone: includeDone,
      status: status,
    );

    return getServiceJobs(status: mappedStatus);
  }

  /// Kompatibilitas detail lama.
  ///
  /// Parameter reportId pada page lama sebaiknya tidak dipakai lagi.
  /// Untuk scheduling baru, ID yang benar adalah bookingId.
  static Future<Map<String, dynamic>?> getDamageReportDetail({
    required int reportId,
  }) async {
    return getServiceJobDetail(bookingId: reportId);
  }

  /// Kompatibilitas method respond lama.
  ///
  /// Untuk scheduling baru:
  /// - status ongoing/proses/in_progress -> startServiceJob
  /// - status finished/completed/selesai -> completeServiceJob
  ///
  /// Catatan:
  /// reportId di method lama dianggap sebagai bookingId.
  static Future<bool> respondToDamageReport({
    required int reportId,
    required String status,
    String? note,

    // Field baru.
    double? finalHourMeter,
    double? totalRepairTime,
    double? totalOperationalTime,
    int? failureCount,
    double? actualOperatingHours,
    double? breakdownHours,

    // Field lama.
    double? mttr,
    double? mtbf,
    double? ma,
  }) async {
    if (reportId <= 0) {
      throw Exception("ID booking tidak valid.");
    }

    final value = status.toLowerCase().trim();

    if (value == "ongoing" ||
        value == "in progress" ||
        value == "in_progress" ||
        value == "diproses" ||
        value == "proses") {
      await startServiceJob(
        bookingId: reportId,
        noteTechnician: note,
      );

      return true;
    }

    if (value == "finished" ||
        value == "completed" ||
        value == "complete" ||
        value == "selesai") {
      await completeServiceJob(
        bookingId: reportId,
        noteTechnician: note,
        finalHourMeter: finalHourMeter,
        totalRepairTime: totalRepairTime,
        totalOperationalTime: totalOperationalTime,
        failureCount: failureCount,
        actualOperatingHours: actualOperatingHours,
        breakdownHours: breakdownHours,
        mttr: mttr,
        mtbf: mtbf,
        ma: ma,
      );

      return true;
    }

    throw Exception(
      "Status '$status' tidak didukung pada maintenance scheduling. Gunakan Ongoing atau Finished.",
    );
  }

  /// Riwayat teknisi.
  ///
  /// Untuk scheduling baru, ambil semua service job teknisi.
  static Future<List<dynamic>> getMyResponses() async {
    return getServiceJobs(status: "all");
  }

  // ---------------------------------------------------------------------------
  // STATUS HELPERS
  // ---------------------------------------------------------------------------

  static String _mapLegacyStatusToServiceJobStatus({
    required bool includeDone,
    String? status,
  }) {
    if (status == null || status.trim().isEmpty) {
      return includeDone ? "all" : "active";
    }

    final value = status.toLowerCase().trim();

    switch (value) {
      case "queue":
        return "queue";

      case "active":
        return "active";

      case "all":
        return "all";

      case "reported":
      case "waiting":
      case "menunggu":
      case "requested":
        return "queue";

      case "approved":
      case "scheduled":
        return "approved";

      case "rescheduled":
        return "rescheduled";

      case "ongoing":
      case "in progress":
      case "in_progress":
      case "diproses":
      case "proses":
        return "in_progress";

      case "finished":
      case "completed":
      case "complete":
      case "selesai":
        return "completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "canceled";

      default:
        return value;
    }
  }
}