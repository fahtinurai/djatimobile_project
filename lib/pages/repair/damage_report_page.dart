import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:djatimobile_project/core/services/auth_service.dart';
import 'package:djatimobile_project/core/services/damage_report_service.dart';
import 'package:djatimobile_project/core/services/service_booking_service.dart';
import 'package:djatimobile_project/pages/dashboard/driver_service_booking_page.dart';

class DamageReportPage extends StatefulWidget {
  const DamageReportPage({super.key});

  @override
  State<DamageReportPage> createState() => _DamageReportPageState();
}

class _DamageReportPageState extends State<DamageReportPage> {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  final TextEditingController _damageTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? _image;

  bool _isLoading = false;
  bool _isLoadingVehicle = true;

  Map<String, dynamic>? _assignment;
  Map<String, dynamic>? _vehicle;

  DateTime? _preferredAt;

  String get _equipmentName {
    return _vehicle?["equipment_name"]?.toString() ?? "";
  }

  String get _plateNumber {
    return _vehicle?["plate_number"]?.toString() ?? "-";
  }

  int? get _vehicleId {
    return int.tryParse(_vehicle?["id"]?.toString() ?? "");
  }

  bool get _canSubmit {
    return !_isLoading &&
        !_isLoadingVehicle &&
        _vehicle != null &&
        _vehicleId != null &&
        _damageTypeController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _image != null;
  }

  @override
  void initState() {
    super.initState();

    _damageTypeController.addListener(_refreshSubmitState);
    _descriptionController.addListener(_refreshSubmitState);

    _loadMyVehicle();
  }

  void _refreshSubmitState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMyVehicle() async {
    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final response = await http.get(
        Uri.parse("$baseUrl/driver/my-vehicle"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MY VEHICLE STATUS: ${response.statusCode}");
      debugPrint("MY VEHICLE BODY: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        setState(() {
          _assignment = body["data"];
          _vehicle = _assignment?["vehicle"];
          _isLoadingVehicle = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _assignment = null;
          _vehicle = null;
          _isLoadingVehicle = false;
        });
      } else {
        throw Exception("Gagal mengambil kendaraan: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _assignment = null;
        _vehicle = null;
        _isLoadingVehicle = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error kendaraan: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickPreferredSchedule() async {
    final now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _preferredAt ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF9A825),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) return;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: _preferredAt != null
          ? TimeOfDay.fromDateTime(_preferredAt!)
          : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF9A825),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return;

    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preferensi jadwal tidak boleh di masa lalu."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _preferredAt = selectedDateTime;
    });
  }

  void _clearPreferredSchedule() {
    setState(() {
      _preferredAt = null;
    });
  }

  String _formatPreferredAt(DateTime? value) {
    if (value == null) {
      return "Opsional - pilih tanggal dan jam yang diinginkan";
    }

    final day = value.day.toString().padLeft(2, "0");
    final month = value.month.toString().padLeft(2, "0");
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, "0");
    final minute = value.minute.toString().padLeft(2, "0");

    return "$day/$month/$year $hour:$minute";
  }

  int? _extractDamageReportId(Map<String, dynamic> reportData) {
    final possibleId =
        reportData["id"] ??
        reportData["damage_report_id"] ??
        reportData["damageReportId"] ??
        reportData["data"]?["id"] ??
        reportData["data"]?["damage_report_id"] ??
        reportData["data"]?["damageReportId"];

    return int.tryParse(possibleId?.toString() ?? "");
  }

  Future<void> _submitReport() async {
    final equipmentName = _equipmentName.trim();
    final damageType = _damageTypeController.text.trim();
    final description = _descriptionController.text.trim();
    final vehicleId = _vehicleId;

    if (_vehicle == null || vehicleId == null || equipmentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kendaraan belum valid atau belum di-assign ke akun driver ini."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (damageType.isEmpty || description.isEmpty || _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi jenis kerusakan, deskripsi, dan foto bukti!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reportData = await DamageReportService.submitReport(
        equipmentName: equipmentName,
        damageType: damageType,
        description: description,
        imageFile: _image!,
      );

      final damageReportId = _extractDamageReportId(reportData);

      if (damageReportId == null) {
        throw Exception(
          "Laporan berhasil dibuat, tetapi ID damage report tidak ditemukan.",
        );
      }

      try {
        await ServiceBookingService.requestBooking(
          damageReportId: damageReportId,
          preferredAt: _preferredAt?.toIso8601String(),
          noteDriver: description,
        );
      } catch (bookingError) {
        throw Exception(
          "Laporan berhasil dibuat, tetapi booking maintenance gagal diajukan: $bookingError",
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Laporan terkirim dan booking maintenance diajukan ke admin.",
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _damageTypeController.clear();
        _descriptionController.clear();
        _image = null;
        _preferredAt = null;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DriverServiceBookingPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _damageTypeController.removeListener(_refreshSubmitState);
    _descriptionController.removeListener(_refreshSubmitState);

    _damageTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    if (_isLoadingVehicle) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFF9A825),
              ),
            ),
            SizedBox(width: 12),
            Text(
              "Mengambil data kendaraan...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_vehicle == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent),
        ),
        child: const Text(
          "Belum ada kendaraan yang di-assign ke akun driver ini.",
          style: TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF9A825)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Assigned Vehicle",
            style: TextStyle(
              color: Color(0xFFF9A825),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _equipmentName.isEmpty ? "Nama unit tidak tersedia" : _equipmentName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Plate Number: $_plateNumber",
            style: const TextStyle(color: Colors.white60),
          ),
          if (_vehicleId != null) ...[
            const SizedBox(height: 4),
            Text(
              "Vehicle ID: $_vehicleId",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _isLoading ? null : _takePhoto,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _image == null ? Colors.white10 : const Color(0xFFF9A825),
            width: 2,
          ),
        ),
        child: _image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_enhance,
                    color: Colors.white24,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap untuk Ambil Foto",
                    style: TextStyle(color: Colors.white24),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _image!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _takePhoto,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPreferredSchedulePicker() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _preferredAt == null ? Colors.white10 : const Color(0xFFF9A825),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading ? null : _pickPreferredSchedule,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: Color(0xFFF9A825),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatPreferredAt(_preferredAt),
                  style: TextStyle(
                    color: _preferredAt == null ? Colors.white38 : Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_preferredAt != null)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                  ),
                  onPressed: _isLoading ? null : _clearPreferredSchedule,
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Maintenance Scheduling Flow",
            style: TextStyle(
              color: Color(0xFFF9A825),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Setelah laporan dikirim, sistem akan otomatis membuat booking maintenance ke admin. Admin akan menentukan jadwal final dan menugaskan teknisi.",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Report Damage",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFlowInfoCard(),
            const SizedBox(height: 20),

            const Text(
              "Unit Name",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildVehicleCard(),

            const SizedBox(height: 20),
            const Text(
              "Damage Type",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildInput(_damageTypeController, "Contoh: Kebocoran Oli"),

            const SizedBox(height: 20),
            const Text(
              "Bukti Foto",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildPhotoPicker(),

            const SizedBox(height: 20),
            const Text(
              "Description",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildInput(
              _descriptionController,
              "Detail masalah kendaraan...",
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            const Text(
              "Preferred Service Schedule",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Opsional. Admin tetap akan menentukan jadwal final.",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            _buildPreferredSchedulePicker(),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit ? Colors.redAccent : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _canSubmit ? _submitReport : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SUBMIT REPORT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              "Status awal booking akan menjadi requested sampai admin menyetujui dan menjadwalkan teknisi.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}