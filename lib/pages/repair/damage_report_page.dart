import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:djatimobile_project/core/services/auth_service.dart';
import 'package:djatimobile_project/core/services/damage_report_service.dart';
import 'package:djatimobile_project/core/services/service_booking_service.dart';

class DamageReportPage extends StatefulWidget {
  const DamageReportPage({super.key});

  @override
  State<DamageReportPage> createState() => _DamageReportPageState();
}

class _DamageReportPageState extends State<DamageReportPage>
    with WidgetsBindingObserver {
  static const String baseUrl = "http://192.168.0.106:8000/api";

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

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

  String get _serialNumber {
    return _vehicle?["serial_number"]?.toString() ??
        _vehicle?["engine_serial_number"]?.toString() ??
        _vehicle?["machine_serial_number"]?.toString() ??
        "-";
  }

  String get _brand {
    return _vehicle?["brand"]?.toString() ?? "-";
  }

  String get _model {
    return _vehicle?["model"]?.toString() ?? "-";
  }

  String get _brandModel {
    final value = "$_brand $_model".trim();

    if (value.isEmpty || value == "- -") {
      return "-";
    }

    return value;
  }

  String get _unitStatus {
    return _vehicle?["status"]?.toString() ??
        _vehicle?["unit_status"]?.toString() ??
        "active";
  }

  num get _initialHourMeter {
    final value = _vehicle?["initial_hour_meter"] ??
        _vehicle?["initial_kpi"] ??
        _vehicle?["hour_meter_awal"] ??
        _vehicle?["kpi_awal"] ??
        _vehicle?["initial_km"] ??
        _vehicle?["km_awal"] ??
        0;

    return num.tryParse(value.toString()) ?? 0;
  }

  num get _currentHourMeter {
    final value = _vehicle?["current_hour_meter"] ??
        _vehicle?["latest_hour_meter"] ??
        _vehicle?["final_hour_meter"] ??
        _vehicle?["hour_meter_terbaru"] ??
        _vehicle?["vehicle_current_hour_meter"] ??
        _vehicle?["vehicle_latest_hour_meter"] ??
        _initialHourMeter;

    return num.tryParse(value.toString()) ?? _initialHourMeter;
  }

  num? get _currentMA {
    final value = _vehicle?["current_ma"] ??
        _vehicle?["ma"] ??
        _vehicle?["mechanical_availability"] ??
        _vehicle?["vehicle_current_ma"];

    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return num.tryParse(value.toString());
  }

  num get _targetAvailability {
    final value = _vehicle?["target_availability"] ??
        _vehicle?["target_ma"] ??
        90;

    return num.tryParse(value.toString()) ?? 90;
  }

  int? get _vehicleId {
    return int.tryParse(_vehicle?["id"]?.toString() ?? "");
  }

  int? get _assignmentId {
    return int.tryParse(_assignment?["id"]?.toString() ?? "");
  }

  String get _assignedAt {
    return _formatDateTime(_assignment?["assigned_at"]);
  }

  bool get _canSubmit {
    return !_isLoading &&
        !_isLoadingVehicle &&
        _vehicle != null &&
        _vehicleId != null &&
        _equipmentName.trim().isNotEmpty &&
        _damageTypeController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _image != null;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _damageTypeController.addListener(_refreshSubmitState);
    _descriptionController.addListener(_refreshSubmitState);

    _loadMyVehicle();
  }

  @override
  void dispose() {
    _damageTypeController.removeListener(_refreshSubmitState);
    _descriptionController.removeListener(_refreshSubmitState);

    _damageTypeController.dispose();
    _descriptionController.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadMyVehicle(showLoading: false);
    }
  }

  void _refreshSubmitState() {
    if (mounted) {
      setState(() {});
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic>? _extractAssignment(dynamic body) {
    final bodyMap = _asMap(body);

    if (bodyMap == null) return null;

    final data = bodyMap["data"];
    final dataMap = _asMap(data);

    if (dataMap != null) {
      return dataMap;
    }

    return bodyMap;
  }

  Map<String, dynamic>? _extractVehicle(Map<String, dynamic>? assignment) {
    if (assignment == null) return null;

    final nestedVehicle = _asMap(assignment["vehicle"]);

    if (nestedVehicle != null) {
      return nestedVehicle;
    }

    final nestedAssignment = _asMap(assignment["assignment"]);
    final vehicleFromNestedAssignment = _asMap(nestedAssignment?["vehicle"]);

    if (vehicleFromNestedAssignment != null) {
      return vehicleFromNestedAssignment;
    }

    final hasDirectVehicleFields =
        assignment.containsKey("equipment_name") ||
        assignment.containsKey("plate_number") ||
        assignment.containsKey("serial_number");

    if (hasDirectVehicleFields) {
      return assignment;
    }

    return null;
  }

  Future<void> _loadMyVehicle({
    bool showLoading = true,
  }) async {
    try {
      if (showLoading && mounted) {
        setState(() {
          _isLoadingVehicle = true;
        });
      }

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

        final assignment = _extractAssignment(body);
        final vehicle = _extractVehicle(assignment);

        setState(() {
          _assignment = assignment;
          _vehicle = vehicle;
          _isLoadingVehicle = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _assignment = null;
          _vehicle = null;
          _isLoadingVehicle = false;
        });
      } else if (response.statusCode == 401) {
        throw Exception("Sesi login sudah berakhir. Silakan login ulang.");
      } else if (response.statusCode == 403) {
        throw Exception("Akun ini tidak memiliki akses sebagai driver.");
      } else {
        String message = "Gagal mengambil kendaraan.";

        try {
          final body = jsonDecode(response.body);
          message = body["message"]?.toString() ?? message;
        } catch (_) {
          message = "Gagal mengambil kendaraan: ${response.statusCode}";
        }

        throw Exception(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _assignment = null;
        _vehicle = null;
        _isLoadingVehicle = false;
      });

      _showSnackBar(
        "Error kendaraan: ${e.toString().replaceFirst("Exception: ", "")}",
        Colors.red,
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
              primary: primaryColor,
              onPrimary: Colors.black,
              surface: cardColor,
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
              primary: primaryColor,
              onPrimary: Colors.black,
              surface: cardColor,
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

      _showSnackBar(
        "Preferensi jadwal tidak boleh di masa lalu.",
        Colors.red,
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

  String _formatDateTime(dynamic value) {
    if (value == null) return "-";

    try {
      final raw = value.toString();
      final normalized =
          raw.contains(" ") && !raw.contains("T") ? raw.replaceFirst(" ", "T") : raw;

      final date = DateTime.parse(normalized).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, "0");
      final minute = date.minute.toString().padLeft(2, "0");

      return "$day/$month/$year $hour:$minute";
    } catch (_) {
      return value.toString();
    }
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return "Aktif";
      case "maintenance":
        return "Maintenance";
      case "inactive":
        return "Tidak Aktif";
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return Colors.greenAccent;
      case "maintenance":
        return Colors.orangeAccent;
      case "inactive":
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case "active":
        return Icons.check_circle_rounded;
      case "maintenance":
        return Icons.car_repair_rounded;
      case "inactive":
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  int? _extractDamageReportId(Map<String, dynamic> reportData) {
    final possibleId = reportData["id"] ??
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
      _showSnackBar(
        "Kendaraan belum valid atau belum di-assign ke akun driver ini.",
        Colors.red,
      );
      return;
    }

    if (damageType.isEmpty || description.isEmpty || _image == null) {
      _showSnackBar(
        "Lengkapi jenis kerusakan, deskripsi, dan foto bukti!",
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reportData = await DamageReportService.submitReport(
        vehicleId: vehicleId,
        assignmentId: _assignmentId,
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

      setState(() {
        _damageTypeController.clear();
        _descriptionController.clear();
        _image = null;
        _preferredAt = null;
      });

      _showSnackBar(
        "Laporan terkirim dan booking maintenance diajukan ke admin.",
        Colors.green,
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        "Error: ${e.toString().replaceFirst("Exception: ", "")}",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    IconData icon = Icons.edit_outlined,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      cursorColor: primaryColor,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 13,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.055),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: primaryColor.withOpacity(0.55),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.30),
            cardColor,
            const Color(0xFF111827),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: primaryColor.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconBadge(
            icon: Icons.report_problem_outlined,
            color: primaryColor,
            size: 54,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Report Damage",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Laporkan kerusakan unit dan ajukan booking maintenance ke admin.",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.lightBlueAccent.withOpacity(0.10),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.lightBlueAccent.withOpacity(0.20),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: Colors.lightBlueAccent,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Setelah laporan dikirim, sistem otomatis membuat booking maintenance ke admin. Admin menentukan jadwal final dan menugaskan teknisi.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    if (_isLoadingVehicle) {
      return _sectionCard(
        title: "Assigned Unit",
        icon: Icons.local_shipping_outlined,
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Mengambil data kendaraan...",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (_vehicle == null) {
      return _sectionCard(
        title: "Assigned Unit",
        icon: Icons.local_shipping_outlined,
        child: _softMessage(
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
          message: "Belum ada kendaraan yang di-assign ke akun driver ini.",
        ),
      );
    }

    final statusColor = _getStatusColor(_unitStatus);
    final currentMA = _currentMA;

    return _sectionCard(
      title: "Assigned Unit",
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(
                icon: _getStatusIcon(_unitStatus),
                color: statusColor,
                size: 48,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _equipmentName.isEmpty
                          ? "Nama unit tidak tersedia"
                          : _equipmentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _brandModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(
                _getStatusLabel(_unitStatus),
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoGrid([
            _InfoItem(
              title: "Plat / Lambung",
              value: _plateNumber,
              icon: Icons.confirmation_number_outlined,
              color: Colors.white,
            ),
            _InfoItem(
              title: "Serial Mesin",
              value: _serialNumber,
              icon: Icons.qr_code_2_rounded,
              color: Colors.white,
            ),
            _InfoItem(
              title: "HM Awal",
              value: _formatNumber(_initialHourMeter),
              icon: Icons.speed_outlined,
              color: primaryColor,
            ),
            _InfoItem(
              title: "HM Terbaru",
              value: _formatNumber(_currentHourMeter),
              icon: Icons.av_timer_outlined,
              color: Colors.orangeAccent,
            ),
            _InfoItem(
              title: "Target MA",
              value: "${_formatNumber(_targetAvailability)}%",
              icon: Icons.track_changes_outlined,
              color: Colors.lightBlueAccent,
            ),
            if (currentMA != null)
              _InfoItem(
                title: "MA Terbaru",
                value: "${_formatNumber(currentMA)}%",
                icon: Icons.analytics_outlined,
                color: Colors.greenAccent,
              ),
          ]),
          const SizedBox(height: 12),
          if (_vehicleId != null || _assignmentId != null)
            _softMessage(
              icon: Icons.info_outline_rounded,
              color: Colors.white54,
              message:
                  "Vehicle ID: ${_vehicleId ?? "-"} • Assignment ID: ${_assignmentId ?? "-"} • Assigned At: $_assignedAt",
            ),
          const SizedBox(height: 10),
          _softMessage(
            icon: Icons.update_rounded,
            color: Colors.orangeAccent,
            message:
                "HM terbaru akan otomatis berubah setelah teknisi menyelesaikan maintenance dan mengisi hour meter terbaru.",
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _isLoading ? null : _takePhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _image == null
                ? Colors.white.withOpacity(0.08)
                : primaryColor.withOpacity(0.65),
            width: 2,
          ),
        ),
        child: _image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_enhance_outlined,
                    color: primaryColor,
                    size: 54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Tap untuk Ambil Foto",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Foto bukti wajib diisi",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _image!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.60),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _takePhoto,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.60),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Foto terlampir",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _preferredAt == null
              ? Colors.white.withOpacity(0.08)
              : primaryColor.withOpacity(0.65),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _isLoading ? null : _pickPreferredSchedule,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _iconBadge(
                icon: Icons.calendar_month_outlined,
                color: primaryColor,
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatPreferredAt(_preferredAt),
                  style: TextStyle(
                    color: _preferredAt == null ? Colors.white38 : Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_preferredAt != null)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                  ),
                  onPressed: _isLoading ? null : _clearPreferredSchedule,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softCardColor.withOpacity(0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.065),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon, subtitle: subtitle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.05,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _infoTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _infoTile(_InfoItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.052),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.icon,
            color: item.color,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            item.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value.isEmpty ? "-" : item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softMessage({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.30),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _iconBadge({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit ? Colors.redAccent : Colors.white12,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _canSubmit ? _submitReport : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                  ),
            label: Text(
              _isLoading ? "MENGIRIM LAPORAN..." : "SUBMIT REPORT",
              style: TextStyle(
                color: _canSubmit ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredHint() {
    final messages = <String>[];

    if (_vehicle == null || _vehicleId == null) {
      messages.add("Unit belum tersedia");
    }

    if (_damageTypeController.text.trim().isEmpty) {
      messages.add("Jenis kerusakan");
    }

    if (_descriptionController.text.trim().isEmpty) {
      messages.add("Deskripsi");
    }

    if (_image == null) {
      messages.add("Foto bukti");
    }

    if (messages.isEmpty) {
      return _softMessage(
        icon: Icons.check_circle_outline_rounded,
        color: Colors.greenAccent,
        message: "Data sudah lengkap. Laporan siap dikirim ke admin.",
      );
    }

    return _softMessage(
      icon: Icons.info_outline_rounded,
      color: Colors.orangeAccent,
      message: "Lengkapi data wajib: ${messages.join(", ")}.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Report Damage",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh Unit",
            onPressed: _isLoading ? null : () => _loadMyVehicle(),
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F1115),
              Color(0xFF111827),
              Color(0xFF0F1115),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: cardColor,
          onRefresh: () => _loadMyVehicle(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildFlowInfoCard(),
                _buildVehicleCard(),
                _sectionCard(
                  title: "Damage Type",
                  icon: Icons.build_circle_outlined,
                  child: _buildInput(
                    _damageTypeController,
                    "Contoh: Kebocoran Oli",
                    icon: Icons.report_problem_outlined,
                  ),
                ),
                _sectionCard(
                  title: "Bukti Foto",
                  icon: Icons.camera_alt_outlined,
                  child: _buildPhotoPicker(),
                ),
                _sectionCard(
                  title: "Description",
                  icon: Icons.description_outlined,
                  child: _buildInput(
                    _descriptionController,
                    "Detail masalah kendaraan...",
                    maxLines: 4,
                    icon: Icons.notes_outlined,
                  ),
                ),
                _sectionCard(
                  title: "Preferred Service Schedule",
                  subtitle: "Opsional. Admin tetap akan menentukan jadwal final.",
                  icon: Icons.event_available_outlined,
                  child: _buildPreferredSchedulePicker(),
                ),
                const SizedBox(height: 16),
                _buildRequiredHint(),
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
        ),
      ),
    );
  }
}

class _InfoItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}