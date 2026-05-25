import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class RepairStatusService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  /// Mengambil damage reports milik driver untuk tracking maintenance.
  ///
  /// Agar UI RepairStatusPage / AnalyticsReportPage bisa menampilkan
  /// maintenance scheduling lengkap, endpoint ini sebaiknya mengirim relasi:
  ///
  /// - vehicle
  /// - driver
  /// - service_booking / latest_service_booking / booking
  /// - service_booking.technician
  /// - latest_technician_response, jika masih dipakai
  static Future<List<dynamic>> getDamageReports() async {
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

    debugPrint("REPAIR STATUS CODE: ${response.statusCode}");
    debugPrint("REPAIR STATUS BODY: ${response.body}");

    final decoded = _safeJsonDecode(response.body);

    if (response.statusCode == 200) {
      return _extractList(decoded);
    }

    throw Exception(_extractErrorMessage(decoded, response.body));
  }

  /// Alias agar bisa dipakai untuk halaman analytics/tracking juga.
  static Future<List<dynamic>> getMaintenanceTracking() {
    return getDamageReports();
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

      final reports = decoded["reports"];
      if (reports is List) {
        return reports;
      }

      final damageReports = decoded["damage_reports"];
      if (damageReports is List) {
        return damageReports;
      }

      final bookings = decoded["bookings"];
      if (bookings is List) {
        return bookings;
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

    return "Gagal mengambil repair status: $fallbackBody";
  }
}