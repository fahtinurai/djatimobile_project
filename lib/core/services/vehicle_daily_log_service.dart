import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class VehicleDailyLogService {
  static const String baseUrl = "http://192.168.0.106:8000/api";

  static Future<List<dynamic>> getLogs() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/driver/vehicle-daily-logs"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("VEHICLE DAILY LOG STATUS: ${response.statusCode}");
    print("VEHICLE DAILY LOG BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded;
      }

      if (decoded is Map<String, dynamic> && decoded["data"] is List) {
        return decoded["data"];
      }

      return [];
    }

    throw Exception("Gagal mengambil vehicle daily logs: ${response.body}");
  }

  static Future<bool> submitLog({
    required String logDate,
    required String shift,
    required double hourMeterStart,
    required double hourMeterEnd,
    required double fuelLiters,
    String? note,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final response = await http.post(
      Uri.parse("$baseUrl/driver/vehicle-daily-logs"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: {
        "log_date": logDate,
        "shift": shift,
        "hour_meter_start": hourMeterStart.toString(),
        "hour_meter_end": hourMeterEnd.toString(),
        "fuel_liters": fuelLiters.toString(),
        "note": note ?? "",
      },
    );

    print("SUBMIT DAILY LOG STATUS: ${response.statusCode}");
    print("SUBMIT DAILY LOG BODY: ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    }

    throw Exception("Gagal menyimpan daily log: ${response.body}");
  }

  static Future<Map<String, dynamic>?> getLogDetail(int logId) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/driver/vehicle-daily-logs/$logId"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("DAILY LOG DETAIL STATUS: ${response.statusCode}");
    print("DAILY LOG DETAIL BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (decoded["data"] is Map<String, dynamic>) {
          return decoded["data"];
        }

        return decoded;
      }

      return null;
    }

    throw Exception("Gagal mengambil detail daily log: ${response.body}");
  }
}