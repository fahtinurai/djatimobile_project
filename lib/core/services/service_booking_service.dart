import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class ServiceBookingService {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";
  static const String backendBaseUrl = "https://proting3-backend-production.up.railway.app";
  static const String storageBaseUrl = "https://proting3-backend-production.up.railway.app/storage";

  static Future<Map<String, dynamic>> requestBooking({
    required int damageReportId,
    String? preferredAt,
    String? noteDriver,
    int? vehicleId,
    int? assignmentId,
  }) async {
    final token = await _getTokenOrThrow();

    if (damageReportId <= 0) {
      throw Exception("Damage report ID tidak valid.");
    }

    final body = <String, String>{};

    if (preferredAt != null && preferredAt.trim().isNotEmpty) {
      body["preferred_at"] = preferredAt.trim();
    }

    if (noteDriver != null && noteDriver.trim().isNotEmpty) {
      body["note_driver"] = noteDriver.trim();
    }

    if (vehicleId != null && vehicleId > 0) {
      body["vehicle_id"] = vehicleId.toString();
    }

    if (assignmentId != null && assignmentId > 0) {
      body["vehicle_assignment_id"] = assignmentId.toString();
      body["assignment_id"] = assignmentId.toString();
    }

    final response = await http.post(
      Uri.parse("$baseUrl/driver/damage-reports/$damageReportId/booking"),
      headers: _headers(token),
      body: body,
    );

    debugPrint("SERVICE BOOKING STATUS: ${response.statusCode}");
    debugPrint("SERVICE BOOKING BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (_isSuccess(response.statusCode)) {
      final data = _extractDataMap(decoded);

      if (data == null) {
        throw Exception("Format response booking tidak sesuai.");
      }

      return _normalizeBookingItem(data);
    }

    throw Exception(
      "Gagal mengajukan booking service: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  static Future<List<dynamic>> getMyBookings() async {
    final token = await _getTokenOrThrow();

    final response = await http.get(
      Uri.parse("$baseUrl/driver/bookings"),
      headers: _headers(token),
    );

    debugPrint("MY BOOKINGS STATUS: ${response.statusCode}");
    debugPrint("MY BOOKINGS BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (response.statusCode == 200) {
      final list = _extractList(decoded);

      return _normalizeBookingList(list);
    }

    throw Exception(
      "Gagal mengambil jadwal booking: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  static Future<Map<String, dynamic>?> getBookingByDamageReport({
    required int damageReportId,
  }) async {
    final token = await _getTokenOrThrow();

    if (damageReportId <= 0) {
      throw Exception("Damage report ID tidak valid.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/driver/damage-reports/$damageReportId/booking"),
      headers: _headers(token),
    );

    debugPrint("BOOKING DETAIL STATUS: ${response.statusCode}");
    debugPrint("BOOKING DETAIL BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (response.statusCode == 200) {
      final data = _extractNullableDataMap(decoded);

      if (data == null) {
        return null;
      }

      return _normalizeBookingItem(data);
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception(
      "Gagal mengambil detail booking: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  static Future<bool> cancelBooking({
    required int bookingId,
  }) async {
    final token = await _getTokenOrThrow();

    if (bookingId <= 0) {
      throw Exception("Booking ID tidak valid.");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/driver/bookings/$bookingId/cancel"),
      headers: _headers(token),
    );

    debugPrint("CANCEL BOOKING STATUS: ${response.statusCode}");
    debugPrint("CANCEL BOOKING BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (_isSuccess(response.statusCode)) {
      return true;
    }

    throw Exception(
      "Gagal membatalkan booking: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  /// Opsional untuk UI: hanya booking aktif.
  static Future<List<dynamic>> getActiveBookings() async {
    final bookings = await getMyBookings();

    return bookings.where((item) {
      if (item is! Map) return false;

      final booking = Map<String, dynamic>.from(item);
      final status = booking["status"]?.toString().toLowerCase() ?? "";

      return status == "requested" ||
          status == "pending" ||
          status == "approved" ||
          status == "scheduled" ||
          status == "rescheduled" ||
          status == "in_progress" ||
          status == "ongoing" ||
          status == "proses";
    }).toList();
  }

  /// Opsional untuk UI: riwayat booking selesai / dibatalkan.
  static Future<List<dynamic>> getCompletedBookings() async {
    final bookings = await getMyBookings();

    return bookings.where((item) {
      if (item is! Map) return false;

      final booking = Map<String, dynamic>.from(item);
      final status = booking["status"]?.toString().toLowerCase() ?? "";

      return status == "completed" ||
          status == "finished" ||
          status == "selesai" ||
          status == "done" ||
          status == "closed" ||
          status == "canceled" ||
          status == "cancelled" ||
          status == "rejected";
    }).toList();
  }

  /// Helper mengambil booking ID dari response.
  static int? extractBookingId(Map<String, dynamic> value) {
    final data = _extractDataMap(value) ?? value;

    final possibleId =
        data["id"] ?? data["booking_id"] ?? data["service_booking_id"];

    return int.tryParse(possibleId?.toString() ?? "");
  }

  /// Helper mengambil status booking dari response.
  static String extractBookingStatus(Map<String, dynamic> value) {
    final data = _extractDataMap(value) ?? value;

    return data["status"]?.toString() ?? "requested";
  }

  // ---------------------------------------------------------------------------
  // NORMALIZER UNTUK FLOW VEHICLE PAGE -> VEHICLE ASSIGNMENT -> DRIVER
  // ---------------------------------------------------------------------------

  static List<dynamic> _normalizeBookingList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizeBookingItem(item);
      }

      if (item is Map) {
        return _normalizeBookingItem(Map<String, dynamic>.from(item));
      }

      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizeBookingItem(Map<String, dynamic> item) {
    final booking = Map<String, dynamic>.from(item);

    final damageReport = _extractDamageReportFromBooking(booking);
    final vehicle = _extractVehicleFromBooking(booking, damageReport);

    final normalizedDamageReport = damageReport == null
        ? null
        : _normalizeDamageReport(damageReport);

    final normalizedVehicle = vehicle == null
        ? null
        : _normalizeVehicle(vehicle);

    /*
    |--------------------------------------------------------------------------
    | Pastikan key snake_case tetap tersedia
    |--------------------------------------------------------------------------
    |
    | UI yang sudah dibuat membaca:
    | - booking["damage_report"]
    | - booking["vehicle"]
    |
    */
    if (normalizedDamageReport != null) {
      booking["damage_report"] = normalizedDamageReport;
    }

    if (normalizedVehicle != null) {
      booking["vehicle"] = normalizedVehicle;

      /*
      |--------------------------------------------------------------------------
      | Jika damage_report punya vehicle, ikut sinkronkan
      |--------------------------------------------------------------------------
      */
      if (booking["damage_report"] is Map) {
        final reportMap = Map<String, dynamic>.from(
          booking["damage_report"] as Map,
        );

        reportMap["vehicle"] = normalizedVehicle;
        booking["damage_report"] = reportMap;
      }
    }

    /*
    |--------------------------------------------------------------------------
    | Alias camelCase agar tetap kompatibel dengan UI lain
    |--------------------------------------------------------------------------
    */
    if (booking["damage_report"] != null && booking["damageReport"] == null) {
      booking["damageReport"] = booking["damage_report"];
    }

    /*
    |--------------------------------------------------------------------------
    | Field ringkas di level booking
    |--------------------------------------------------------------------------
    */
    if (normalizedVehicle != null) {
      booking["equipment_name"] ??= normalizedVehicle["equipment_name"];
      booking["plate_number"] ??= normalizedVehicle["plate_number"];
      booking["serial_number"] ??= normalizedVehicle["serial_number"];
      booking["initial_kpi"] ??= normalizedVehicle["initial_kpi"];
      booking["initial_hour_meter"] ??=
          normalizedVehicle["initial_hour_meter"];
      booking["target_availability"] ??=
          normalizedVehicle["target_availability"];
      booking["vehicle_status"] ??= normalizedVehicle["status"];
    }

    if (normalizedDamageReport != null) {
      booking["damage_type"] ??= normalizedDamageReport["damage_type"];
      booking["description"] ??= normalizedDamageReport["description"];
      booking["image"] ??= normalizedDamageReport["image"];
      booking["image_url"] ??= normalizedDamageReport["image_url"];
    }

    return booking;
  }

  static Map<String, dynamic>? _extractDamageReportFromBooking(
    Map<String, dynamic> booking,
  ) {
    final snake = booking["damage_report"];
    if (snake is Map<String, dynamic>) {
      return snake;
    }

    if (snake is Map) {
      return Map<String, dynamic>.from(snake);
    }

    final camel = booking["damageReport"];
    if (camel is Map<String, dynamic>) {
      return camel;
    }

    if (camel is Map) {
      return Map<String, dynamic>.from(camel);
    }

    final report = booking["report"];
    if (report is Map<String, dynamic>) {
      return report;
    }

    if (report is Map) {
      return Map<String, dynamic>.from(report);
    }

    final hasDirectDamageReportFields = booking["damage_type"] != null ||
        booking["description"] != null ||
        booking["image"] != null ||
        booking["image_url"] != null;

    if (hasDirectDamageReportFields) {
      return booking;
    }

    return null;
  }

  static Map<String, dynamic>? _extractVehicleFromBooking(
    Map<String, dynamic> booking,
    Map<String, dynamic>? damageReport,
  ) {
    final directVehicle = booking["vehicle"];

    if (directVehicle is Map<String, dynamic>) {
      return directVehicle;
    }

    if (directVehicle is Map) {
      return Map<String, dynamic>.from(directVehicle);
    }

    final reportVehicle = damageReport?["vehicle"];

    if (reportVehicle is Map<String, dynamic>) {
      return reportVehicle;
    }

    if (reportVehicle is Map) {
      return Map<String, dynamic>.from(reportVehicle);
    }

    final hasVehicleFields = booking["equipment_name"] != null ||
        booking["plate_number"] != null ||
        booking["serial_number"] != null ||
        booking["initial_kpi"] != null ||
        booking["initial_hour_meter"] != null;

    if (hasVehicleFields) {
      return booking;
    }

    final hasReportVehicleFields = damageReport?["vehicle_equipment_name"] != null ||
        damageReport?["vehicle_plate_number"] != null ||
        damageReport?["vehicle_serial_number"] != null ||
        damageReport?["vehicle_initial_kpi"] != null ||
        damageReport?["vehicle_initial_hour_meter"] != null;

    if (hasReportVehicleFields && damageReport != null) {
      return {
        "id": damageReport["vehicle_id"],
        "equipment_name": damageReport["vehicle_equipment_name"],
        "plate_number": damageReport["vehicle_plate_number"],
        "serial_number": damageReport["vehicle_serial_number"],
        "initial_kpi": damageReport["vehicle_initial_kpi"],
        "initial_hour_meter": damageReport["vehicle_initial_hour_meter"],
        "target_availability": damageReport["vehicle_target_availability"],
        "status": damageReport["vehicle_status"],
      };
    }

    return null;
  }

  static Map<String, dynamic> _normalizeDamageReport(
    Map<String, dynamic> damageReport,
  ) {
    final report = Map<String, dynamic>.from(damageReport);

    final imageRaw = report["image_url"] ??
        report["imageUrl"] ??
        report["image"];

    final imageUrl = _resolveImageUrl(imageRaw);

    if (imageUrl != null) {
      report["image_url"] = imageUrl;
      report["imageUrl"] = imageUrl;
    }

    /*
    |--------------------------------------------------------------------------
    | Jika backend mengirim vehicle_* dari DamageReport model,
    | tetap pertahankan agar UI analytics/task detail bisa membacanya.
    |--------------------------------------------------------------------------
    */
    report["vehicle_equipment_name"] ??=
        report["vehicle"] is Map ? report["vehicle"]["equipment_name"] : null;

    report["vehicle_plate_number"] ??=
        report["vehicle"] is Map ? report["vehicle"]["plate_number"] : null;

    report["vehicle_serial_number"] ??=
        report["vehicle"] is Map ? report["vehicle"]["serial_number"] : null;

    report["vehicle_initial_kpi"] ??=
        report["vehicle"] is Map ? report["vehicle"]["initial_kpi"] : null;

    report["vehicle_initial_hour_meter"] ??=
        report["vehicle"] is Map
            ? (report["vehicle"]["initial_hour_meter"] ??
                report["vehicle"]["initial_kpi"])
            : null;

    report["vehicle_target_availability"] ??=
        report["vehicle"] is Map
            ? (report["vehicle"]["target_availability"] ?? 90)
            : 90;

    report["vehicle_status"] ??=
        report["vehicle"] is Map ? (report["vehicle"]["status"] ?? "active") : "active";

    return report;
  }

  static Map<String, dynamic> _normalizeVehicle(
    Map<String, dynamic> vehicle,
  ) {
    final normalized = Map<String, dynamic>.from(vehicle);

    final initialValue = normalized["initial_hour_meter"] ??
        normalized["initial_kpi"] ??
        normalized["hour_meter_awal"] ??
        normalized["kpi_awal"] ??
        0;

    normalized["initial_kpi"] ??= initialValue;
    normalized["initial_hour_meter"] ??= initialValue;

    normalized["target_availability"] ??=
        normalized["target_ma"] ?? 90;

    normalized["target_ma"] ??=
        normalized["target_availability"] ?? 90;

    normalized["status"] ??=
        normalized["unit_status"] ?? "active";

    normalized["unit_status"] ??=
        normalized["status"] ?? "active";

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

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  static Future<String> _getTokenOrThrow() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    return token;
  }

  static Map<String, String> _headers(String token) {
    return {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
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

  static Map<String, dynamic>? _extractDataMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final data = decoded["data"];

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      return decoded;
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);
      return _extractDataMap(mapped);
    }

    return null;
  }

  static Map<String, dynamic>? _extractNullableDataMap(dynamic decoded) {
    if (decoded == null) {
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded["data"];

      if (data == null) {
        if (decoded.isNotEmpty) {
          return decoded;
        }

        return null;
      }

      if (data is Map<String, dynamic>) {
        return data;
      }

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);
      return _extractNullableDataMap(mapped);
    }

    return null;
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

        final bookingsFromData = data["bookings"];
        if (bookingsFromData is List) {
          return bookingsFromData;
        }

        final serviceBookingsFromData = data["service_bookings"];
        if (serviceBookingsFromData is List) {
          return serviceBookingsFromData;
        }
      }

      final bookings = decoded["bookings"];
      if (bookings is List) {
        return bookings;
      }

      final serviceBookings = decoded["service_bookings"];
      if (serviceBookings is List) {
        return serviceBookings;
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
      return fallbackBody;
    }

    return "Terjadi kesalahan pada server.";
  }
}