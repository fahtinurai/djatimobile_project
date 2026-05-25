import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class RepairService {
  static Future<void> submitReport({
    required String equipmentName,
    required String damageType,
    required String description,
    required String imagePath,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final uri = Uri.parse("${ApiService.baseUrl}/driver/damage-reports");

    final request = http.MultipartRequest("POST", uri);

    request.headers.addAll({
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    });

    request.fields.addAll({
      "equipment_name": equipmentName,
      "damage_type": damageType,
      "description": description,
    });

    request.files.add(
      await http.MultipartFile.fromPath(
        "image",
        imagePath,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print("REPAIR REPORT STATUS: ${response.statusCode}");
    print("REPAIR REPORT BODY: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Gagal kirim data: ${response.body}");
    }
  }

  static Future<http.Response> getRepairStatus() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("Token tidak ditemukan. Silakan login ulang.");
    }

    final uri = Uri.parse("${ApiService.baseUrl}/driver/damage-reports");

    final response = await http.get(
      uri,
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    print("REPAIR STATUS CODE: ${response.statusCode}");
    print("REPAIR STATUS BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("Gagal mengambil repair status: ${response.body}");
    }

    return response;
  }
}