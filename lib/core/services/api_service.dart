import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../constants/api_constants.dart';

class ApiService {
  static const String baseUrl = ApiConstants.baseUrl;
  
  // HEADER (pakai token kalau ada)
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();

    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // LOGIN (tanpa token)
  static Future<Map<String, dynamic>> login(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      return {
        "statusCode": response.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {"message": "Error: $e"},
      };
    }
  }

  // GET
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await _headers();

      final response = await http.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      return {
        "statusCode": response.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {"message": "Error: $e"},
      };
    }
  }

  // POST
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await _headers();

      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      return {
        "statusCode": response.statusCode,
        "data": data,
      };
    } catch (e) {
      return {
        "statusCode": 500,
        "data": {"message": "Error: $e"},
      };
    }
  }
}