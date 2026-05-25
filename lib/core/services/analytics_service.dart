import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class AnalyticsService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  static Future<Map<String, dynamic>> getDriverAnalytics() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final response = await http.get(
      Uri.parse("$baseUrl/driver/analytics"),
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("ANALYTICS STATUS: ${response.statusCode}");
    print("ANALYTICS BODY: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        if (decoded["data"] is Map<String, dynamic>) {
          return decoded["data"];
        }

        return decoded;
      }

      throw Exception("Format response analytics tidak sesuai.");
    }

    throw Exception("Gagal mengambil analytics: ${response.body}");
  }
}