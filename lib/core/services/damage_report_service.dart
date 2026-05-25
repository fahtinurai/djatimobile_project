import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class DamageReportService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  /// Submit laporan kerusakan driver.
  ///
  /// Alur maintenance scheduling:
  /// 1. Driver kirim damage report.
  /// 2. Backend membuat damage_reports.
  /// 3. Response harus mengembalikan damage_report.id.
  /// 4. UI memakai ID itu untuk request booking maintenance ke admin.
  ///
  /// Catatan:
  /// - equipmentName tetap dipertahankan agar kompatibel dengan backend lama.
  /// - vehicleId ditambahkan agar lebih aman untuk backend baru.
  static Future<Map<String, dynamic>> submitReport({
    int? vehicleId,
    required String equipmentName,
    required String damageType,
    required String description,
    required File imageFile,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    if (damageType.trim().isEmpty) {
      throw Exception("Jenis kerusakan wajib diisi.");
    }

    if (description.trim().isEmpty) {
      throw Exception("Deskripsi kerusakan wajib diisi.");
    }

    if (!await imageFile.exists()) {
      throw Exception("File foto tidak ditemukan.");
    }

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/driver/damage-reports"),
    );

    request.headers.addAll({
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });

    request.fields.addAll({
      "equipment_name": equipmentName.trim(),
      "damage_type": damageType.trim(),
      "description": description.trim(),
    });

    if (vehicleId != null) {
      request.fields["vehicle_id"] = vehicleId.toString();
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        "image",
        imageFile.path,
      ),
    );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    debugPrint("REPORT STATUS: ${streamedResponse.statusCode}");
    debugPrint("REPORT BODY: $responseBody");

    final decoded = _safeJsonDecode(responseBody);

    if (streamedResponse.statusCode == 200 ||
        streamedResponse.statusCode == 201) {
      final data = _extractDataMap(decoded);

      if (data == null) {
        throw Exception("Format response damage report tidak sesuai.");
      }

      final damageReportId = extractDamageReportId(data);

      if (damageReportId == null) {
        throw Exception(
          "Laporan berhasil dibuat, tetapi ID damage report tidak ditemukan.",
        );
      }

      return data;
    }

    throw Exception(_extractErrorMessage(decoded, responseBody));
  }

  /// Mengambil ID damage report dari berbagai kemungkinan format response.
  ///
  /// Format yang didukung:
  /// - { id: 1 }
  /// - { damage_report_id: 1 }
  /// - { damageReportId: 1 }
  /// - { data: { id: 1 } }
  /// - { data: { damage_report_id: 1 } }
  static int? extractDamageReportId(Map<String, dynamic> value) {
    final data = _extractDataMap(value) ?? value;

    final possibleId = data["id"] ??
        data["damage_report_id"] ??
        data["damageReportId"] ??
        value["id"] ??
        value["damage_report_id"] ??
        value["damageReportId"];

    return int.tryParse(possibleId?.toString() ?? "");
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
      if (decoded["data"] is Map<String, dynamic>) {
        return decoded["data"] as Map<String, dynamic>;
      }

      return decoded;
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);

      if (mapped["data"] is Map) {
        return Map<String, dynamic>.from(mapped["data"] as Map);
      }

      return mapped;
    }

    return null;
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

    return "Gagal mengirim laporan: $fallbackBody";
  }
}