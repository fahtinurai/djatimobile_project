import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:djatimobile_project/core/services/auth_service.dart';

class DamageReportService {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";
  static const String backendBaseUrl = "https://proting3-backend-production.up.railway.app";
  static const String storageBaseUrl = "https://proting3-backend-production.up.railway.app/storage";

  /// Submit laporan kerusakan driver.
  ///
  /// Flow tetap dipertahankan:
  /// 1. Driver kirim damage report.
  /// 2. Backend membuat damage_reports.
  /// 3. Response mengembalikan damage_report.id.
  /// 4. UI memakai ID itu untuk request booking maintenance ke admin.
  ///
  /// Penyesuaian HM terbaru:
  /// - currentHourMeter bersifat opsional.
  /// - HM terbaru tetap sumber utamanya dari backend vehicles.current_hour_meter.
  /// - Field ini dikirim hanya sebagai data pendukung agar backend lama/baru
  ///   tetap bisa menerima alias jika diperlukan.
  static Future<Map<String, dynamic>> submitReport({
    int? vehicleId,
    int? assignmentId,
    required String equipmentName,
    required String damageType,
    required String description,
    required File imageFile,
    num? currentHourMeter,
    num? latestHourMeter,
    num? finalHourMeter,
    num? currentMa,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final cleanEquipmentName = equipmentName.trim();
    final cleanDamageType = damageType.trim();
    final cleanDescription = description.trim();

    if (cleanEquipmentName.isEmpty && vehicleId == null) {
      throw Exception(
        "Kendaraan belum valid. Pastikan kendaraan sudah di-assign ke akun driver ini.",
      );
    }

    if (cleanDamageType.isEmpty) {
      throw Exception("Jenis kerusakan wajib diisi.");
    }

    if (cleanDescription.isEmpty) {
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

    /*
    |--------------------------------------------------------------------------
    | FIELD LAMA YANG TETAP DIPERTAHANKAN
    |--------------------------------------------------------------------------
    */
    request.fields["equipment_name"] = cleanEquipmentName;
    request.fields["damage_type"] = cleanDamageType;
    request.fields["description"] = cleanDescription;

    /*
    |--------------------------------------------------------------------------
    | FIELD BARU UNTUK RELASI VEHICLE ASSIGNMENT
    |--------------------------------------------------------------------------
    */
    if (vehicleId != null && vehicleId > 0) {
      request.fields["vehicle_id"] = vehicleId.toString();
    }

    if (assignmentId != null && assignmentId > 0) {
      request.fields["vehicle_assignment_id"] = assignmentId.toString();
      request.fields["assignment_id"] = assignmentId.toString();
    }

    /*
    |--------------------------------------------------------------------------
    | FIELD OPSIONAL HM TERBARU
    |--------------------------------------------------------------------------
    |
    | Driver tidak mengubah HM terbaru dari halaman damage report.
    | Tetapi jika page sudah punya value dari assigned vehicle, field ini bisa
    | ikut dikirim sebagai snapshot pendukung.
    |
    | Update resmi HM terbaru tetap dilakukan teknisi lewat complete service.
    |
    */
    final hmTerbaru = currentHourMeter ?? latestHourMeter ?? finalHourMeter;

    if (hmTerbaru != null) {
      request.fields["current_hour_meter"] = hmTerbaru.toString();
      request.fields["latest_hour_meter"] = hmTerbaru.toString();
      request.fields["final_hour_meter"] = hmTerbaru.toString();
      request.fields["hour_meter_terbaru"] = hmTerbaru.toString();
    }

    if (currentMa != null) {
      request.fields["current_ma"] = currentMa.toString();
      request.fields["ma"] = currentMa.toString();
      request.fields["mechanical_availability"] = currentMa.toString();
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

      final normalizedData = _normalizeDamageReport(data);

      final damageReportId = extractDamageReportId(normalizedData);

      if (damageReportId == null) {
        throw Exception(
          "Laporan berhasil dibuat, tetapi ID damage report tidak ditemukan.",
        );
      }

      return normalizedData;
    }

    if (streamedResponse.statusCode == 401) {
      throw Exception("Sesi login sudah berakhir. Silakan login ulang.");
    }

    if (streamedResponse.statusCode == 403) {
      throw Exception("Akun ini tidak memiliki akses sebagai driver.");
    }

    if (streamedResponse.statusCode == 404) {
      throw Exception("Endpoint laporan kerusakan tidak ditemukan.");
    }

    if (streamedResponse.statusCode == 413) {
      throw Exception(
        "Ukuran foto terlalu besar. Gunakan foto dengan ukuran lebih kecil.",
      );
    }

    if (streamedResponse.statusCode == 422) {
      throw Exception(_extractErrorMessage(decoded, responseBody));
    }

    throw Exception(_extractErrorMessage(decoded, responseBody));
  }

  /// Mengambil ID damage report dari berbagai kemungkinan format response.
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

  /*
  |--------------------------------------------------------------------------
  | NORMALIZER RESPONSE DAMAGE REPORT
  |--------------------------------------------------------------------------
  |
  | Tujuannya supaya response dari backend langsung aman dipakai oleh:
  | - DamageReportPage
  | - RepairStatusPage
  | - AnalyticsReportPage
  | - TaskDetailPage
  |
  | Termasuk field HM terbaru:
  | - vehicle.current_hour_meter
  | - vehicle.latest_hour_meter
  | - vehicle.final_hour_meter
  | - vehicle.hour_meter_terbaru
  | - vehicle_current_hour_meter
  | - vehicle_hour_meter_terbaru
  |
  */

  static Map<String, dynamic> _normalizeDamageReport(
    Map<String, dynamic> data,
  ) {
    final report = Map<String, dynamic>.from(data);

    final imageRaw = report["image_url"] ?? report["imageUrl"] ?? report["image"];
    final imageUrl = _resolveImageUrl(imageRaw);

    if (imageUrl != null) {
      report["image_url"] = imageUrl;
      report["imageUrl"] = imageUrl;
    }

    final vehicle = _extractVehicleMap(report);

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
      report["vehicle_final_hour_meter"] ??=
          normalizedVehicle["final_hour_meter"];
      report["vehicle_hour_meter_terbaru"] ??=
          normalizedVehicle["hour_meter_terbaru"];

      report["vehicle_target_availability"] ??=
          normalizedVehicle["target_availability"];
      report["vehicle_target_ma"] ??= normalizedVehicle["target_ma"];

      report["vehicle_current_ma"] ??= normalizedVehicle["current_ma"];
      report["vehicle_ma"] ??= normalizedVehicle["ma"];
      report["vehicle_mechanical_availability"] ??=
          normalizedVehicle["mechanical_availability"];

      report["vehicle_status"] ??= normalizedVehicle["status"];
    }

    return report;
  }

  static Map<String, dynamic>? _extractVehicleMap(
    Map<String, dynamic> report,
  ) {
    final vehicle = report["vehicle"];

    if (vehicle is Map<String, dynamic>) {
      return vehicle;
    }

    if (vehicle is Map) {
      return Map<String, dynamic>.from(vehicle);
    }

    final hasVehicleAlias = report["vehicle_equipment_name"] != null ||
        report["vehicle_plate_number"] != null ||
        report["vehicle_serial_number"] != null ||
        report["vehicle_initial_kpi"] != null ||
        report["vehicle_initial_hour_meter"] != null ||
        report["vehicle_current_hour_meter"] != null ||
        report["vehicle_latest_hour_meter"] != null ||
        report["vehicle_final_hour_meter"] != null ||
        report["vehicle_hour_meter_terbaru"] != null ||
        report["current_hour_meter"] != null ||
        report["latest_hour_meter"] != null ||
        report["final_hour_meter"] != null ||
        report["hour_meter_terbaru"] != null;

    if (hasVehicleAlias) {
      return {
        "id": report["vehicle_id"],
        "equipment_name": report["vehicle_equipment_name"],
        "plate_number": report["vehicle_plate_number"],
        "serial_number": report["vehicle_serial_number"],
        "initial_kpi": report["vehicle_initial_kpi"],
        "initial_hour_meter": report["vehicle_initial_hour_meter"],
        "current_hour_meter": report["vehicle_current_hour_meter"] ??
            report["current_hour_meter"],
        "latest_hour_meter": report["vehicle_latest_hour_meter"] ??
            report["latest_hour_meter"],
        "final_hour_meter": report["vehicle_final_hour_meter"] ??
            report["final_hour_meter"],
        "hour_meter_terbaru": report["vehicle_hour_meter_terbaru"] ??
            report["hour_meter_terbaru"],
        "target_availability": report["vehicle_target_availability"],
        "target_ma": report["vehicle_target_ma"],
        "current_ma": report["vehicle_current_ma"] ?? report["current_ma"],
        "ma": report["vehicle_ma"] ?? report["ma"],
        "mechanical_availability": report["vehicle_mechanical_availability"] ??
            report["mechanical_availability"],
        "status": report["vehicle_status"],
      };
    }

    return null;
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

    final currentValue = normalized["current_hour_meter"] ??
        normalized["latest_hour_meter"] ??
        normalized["final_hour_meter"] ??
        normalized["hour_meter_terbaru"] ??
        normalized["vehicle_current_hour_meter"] ??
        normalized["vehicle_latest_hour_meter"] ??
        initialValue;

    normalized["current_hour_meter"] ??= currentValue;
    normalized["latest_hour_meter"] ??= currentValue;
    normalized["final_hour_meter"] ??= currentValue;
    normalized["hour_meter_terbaru"] ??= currentValue;

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

  /*
  |--------------------------------------------------------------------------
  | JSON HELPERS
  |--------------------------------------------------------------------------
  */

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

      if (decoded["data"] is Map) {
        return Map<String, dynamic>.from(decoded["data"] as Map);
      }

      if (decoded["damage_report"] is Map<String, dynamic>) {
        return decoded["damage_report"] as Map<String, dynamic>;
      }

      if (decoded["damage_report"] is Map) {
        return Map<String, dynamic>.from(decoded["damage_report"] as Map);
      }

      return decoded;
    }

    if (decoded is Map) {
      final mapped = Map<String, dynamic>.from(decoded);

      if (mapped["data"] is Map) {
        return Map<String, dynamic>.from(mapped["data"] as Map);
      }

      if (mapped["damage_report"] is Map) {
        return Map<String, dynamic>.from(mapped["damage_report"] as Map);
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
      return "Gagal mengirim laporan: $fallbackBody";
    }

    return "Gagal mengirim laporan kerusakan.";
  }
}
