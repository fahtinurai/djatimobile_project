import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class ServiceBookingService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  /// Driver mengajukan booking maintenance dari damage report.
  ///
  /// Endpoint backend:
  /// POST /api/driver/damage-reports/{damageReportId}/booking
  ///
  /// Alur:
  /// 1. Driver sudah membuat damage report.
  /// 2. Flutter mengambil damage_report_id.
  /// 3. Flutter memanggil requestBooking().
  /// 4. Backend membuat service_bookings.status = requested.
  /// 5. Admin menerima notifikasi dan menjadwalkan teknisi.
  static Future<Map<String, dynamic>> requestBooking({
    required int damageReportId,
    String? preferredAt,
    String? noteDriver,
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

      return data;
    }

    throw Exception(
      "Gagal mengajukan booking service: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  /// Mengambil semua booking maintenance milik driver.
  ///
  /// Endpoint backend:
  /// GET /api/driver/bookings
  ///
  /// Response ideal:
  /// {
  ///   "data": [
  ///     {
  ///       "id": 1,
  ///       "status": "approved",
  ///       "damage_report": {...},
  ///       "vehicle": {...},
  ///       "driver": {...},
  ///       "technician": {...}
  ///     }
  ///   ]
  /// }
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
      return _extractList(decoded);
    }

    throw Exception(
      "Gagal mengambil jadwal booking: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  /// Mengambil booking berdasarkan damage_report_id.
  ///
  /// Endpoint backend:
  /// GET /api/driver/damage-reports/{damageReportId}/booking
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
      return _extractNullableDataMap(decoded);
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw Exception(
      "Gagal mengambil detail booking: ${_extractErrorMessage(decoded, response.body)}",
    );
  }

  /// Driver membatalkan booking.
  ///
  /// Endpoint backend:
  /// POST /api/driver/bookings/{bookingId}/cancel
  ///
  /// Backend kamu mengizinkan cancel untuk status:
  /// requested, approved, rescheduled.
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
          status == "approved" ||
          status == "rescheduled" ||
          status == "in_progress";
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

    if (fallbackBody.trim().isNotEmpty) {
      return fallbackBody;
    }

    return "Terjadi kesalahan pada server.";
  }
}