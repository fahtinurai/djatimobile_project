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

  static List<dynamic> _parseList(String body) {
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
        final paginatedData = data["data"];

        if (paginatedData is List) {
          return paginatedData;
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
    }

    return [];
  }

  static Map<String, dynamic>? _parseMap(String body) {
    final decoded = _safeJsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      if (decoded["data"] is Map<String, dynamic>) {
        return decoded["data"] as Map<String, dynamic>;
      }

      if (decoded["data"] is Map) {
        return Map<String, dynamic>.from(decoded["data"] as Map);
      }

      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return null;
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

        return firstValue.toString();
      }
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);
      final message = mapped["message"]?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    return "$fallback: ${response.body}";
  }

  static bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
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
      return _parseList(response.body);
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
      return _parseMap(response.body);
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

    if (noteTechnician != null && noteTechnician.trim().isNotEmpty) {
      body["note_technician"] = noteTechnician.trim();
    }

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
      return _parseMap(response.body);
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
  /// Efek backend:
  /// - status -> completed
  /// - completed_at -> now()
  /// - FCM ke driver: servis selesai
  static Future<Map<String, dynamic>?> completeServiceJob({
    required int bookingId,
    String? noteTechnician,
    double? mttr,
    double? mtbf,
    double? ma,
  }) async {
    if (bookingId <= 0) {
      throw Exception("ID booking tidak valid.");
    }

    final uri = Uri.parse("$baseUrl/technician/service-jobs/$bookingId/complete");

    final body = <String, String>{};

    if (noteTechnician != null && noteTechnician.trim().isNotEmpty) {
      body["note_technician"] = noteTechnician.trim();
    }

    if (mttr != null) {
      body["mttr"] = mttr.toStringAsFixed(2);
    }

    if (mtbf != null) {
      body["mtbf"] = mtbf.toStringAsFixed(2);
    }

    if (ma != null) {
      body["ma"] = ma.toStringAsFixed(1);
    }

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
      return _parseMap(response.body);
    }

    throw Exception(
      _errorMessage(response, "Gagal menyelesaikan service job"),
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