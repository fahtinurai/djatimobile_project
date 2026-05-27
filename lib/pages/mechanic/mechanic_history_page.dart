import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';

// -------------------------------------------------------------------
// 1. HALAMAN UTAMA: REPAIR / MAINTENANCE HISTORY TEKNISI
// -------------------------------------------------------------------
class MechanicHistoryPage extends StatefulWidget {
  const MechanicHistoryPage({super.key});

  @override
  State<MechanicHistoryPage> createState() => _MechanicHistoryPageState();
}

class _MechanicHistoryPageState extends State<MechanicHistoryPage> {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadServiceJobs();
  }

  Future<void> _loadServiceJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final response = await http.get(
        Uri.parse("$baseUrl/technician/service-jobs?status=all"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MECHANIC HISTORY STATUS: ${response.statusCode}");
      debugPrint("MECHANIC HISTORY BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> jobs = [];

        if (decoded is List) {
          jobs = decoded;
        } else if (decoded is Map<String, dynamic> && decoded["data"] is List) {
          jobs = decoded["data"];
        }

        if (!mounted) return;

        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      } else {
        throw Exception("Gagal mengambil history job teknisi: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> job) {
    return _asMap(job["damage_report"]);
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> job) {
    final directVehicle = _asMap(job["vehicle"]);
    if (directVehicle != null) return directVehicle;

    final report = _getDamageReport(job);
    return _asMap(report?["vehicle"]);
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> job) {
    final directDriver = _asMap(job["driver"]);
    if (directDriver != null) return directDriver;

    final report = _getDamageReport(job);
    return _asMap(report?["driver"]);
  }

  String _getUnitName(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    return "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> job) {
    final vehicle = _getVehicle(job);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDamageType(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    return report?["damage_type"]?.toString() ??
        job["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> job) {
    final report = _getDamageReport(job);

    return report?["description"]?.toString() ??
        job["description"]?.toString() ??
        "-";
  }

  String _getDriverName(Map<String, dynamic> job) {
    final driver = _getDriver(job);

    if (driver == null) {
      return "Unknown Driver";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "Unknown Driver";
  }

  String _formatDateTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final date = DateTime.parse(raw).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return "$day-$month-$year $hour:$minute WIB";
    } catch (_) {
      return raw;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "approved":
        return "Ready to Start";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
        return "In Progress";

      case "completed":
      case "finished":
      case "selesai":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "requested":
        return "Requested";

      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "approved":
      case "ready to start":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in_progress":
      case "in progress":
        return Colors.amber;

      case "completed":
      case "finished":
      case "selesai":
        return Colors.green;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Colors.redAccent;

      case "requested":
        return Colors.orange;

      default:
        return Colors.white54;
    }
  }

  bool _isCompleted(Map<String, dynamic> job) {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" ||
        status == "finished" ||
        status == "selesai";
  }

  bool _isClosed(Map<String, dynamic> job) {
    final status = job["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" ||
        status == "finished" ||
        status == "selesai" ||
        status == "canceled" ||
        status == "cancelled" ||
        status == "dibatalkan";
  }

  bool _isValidKpiValue(dynamic value) {
    if (value == null) return false;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return false;

    final number = double.tryParse(text);

    if (number == null) return false;

    return number > 0;
  }

  bool _hasKpi(Map<String, dynamic> job) {
    return _isValidKpiValue(job["mttr"]) ||
        _isValidKpiValue(job["mtbf"]) ||
        _isValidKpiValue(job["ma"]);
  }

  String _formatKpi(dynamic value, {int fractionDigits = 2}) {
    if (value == null) return "-";

    final number = double.tryParse(value.toString());

    if (number == null) return value.toString();

    return number.toStringAsFixed(fractionDigits);
  }

  List<String> _getRepairDetails(Map<String, dynamic> job) {
    final details = <String>[];

    final damageType = _getDamageType(job);
    final description = _getDescription(job);
    final status = _getStatusLabel(job["status"]?.toString() ?? "-");

    final scheduledAt = _formatDateTime(job["scheduled_at"]);
    final startedAt = _formatDateTime(job["started_at"]);
    final completedAt = _formatDateTime(job["completed_at"]);
    final estimatedFinishAt = _formatDateTime(job["estimated_finish_at"]);

    final noteDriver = job["note_driver"]?.toString() ?? "-";
    final noteAdmin = job["note_admin"]?.toString() ?? "-";
    final noteTechnician = job["note_technician"]?.toString() ?? "-";

    if (damageType != "-") {
      details.add("Jenis kerusakan: $damageType");
    }

    if (description != "-") {
      details.add("Deskripsi driver: $description");
    }

    if (noteDriver != "-") {
      details.add("Catatan driver: $noteDriver");
    }

    if (scheduledAt != "-") {
      details.add("Jadwal admin: $scheduledAt");
    }

    if (estimatedFinishAt != "-") {
      details.add("Estimasi selesai: $estimatedFinishAt");
    }

    if (noteAdmin != "-") {
      details.add("Catatan admin: $noteAdmin");
    }

    if (startedAt != "-") {
      details.add("Mulai dikerjakan: $startedAt");
    }

    if (completedAt != "-") {
      details.add("Selesai dikerjakan: $completedAt");
    }

    if (noteTechnician != "-") {
      details.add("Catatan teknisi: $noteTechnician");
    }

    if (_isValidKpiValue(job["mttr"])) {
      details.add("MTTR: ${_formatKpi(job["mttr"])} hrs");
    }

    if (_isValidKpiValue(job["mtbf"])) {
      details.add("MTBF: ${_formatKpi(job["mtbf"])} hrs");
    }

    if (_isValidKpiValue(job["ma"])) {
      details.add("MA: ${_formatKpi(job["ma"], fractionDigits: 1)}%");
    }

    details.add("Status akhir: $status");

    return details;
  }

  void _showKpiForm(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateKpiModal(
        job: job,
        unitName: _getUnitName(job),
        onSuccess: _loadServiceJobs,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF9A825),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadServiceJobs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                ),
                child: const Text(
                  "Coba Lagi",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadServiceJobs,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.assignment_outlined,
              color: Colors.white24,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada history maintenance.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 8),
            Text(
              "History akan muncul setelah admin menjadwalkan dan teknisi memproses job.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white24,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadServiceJobs,
      color: const Color(0xFFF9A825),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final item = _jobs[index];

          if (item is! Map) return const SizedBox.shrink();

          final job = Map<String, dynamic>.from(item);

          final bookingId = job["id"]?.toString() ?? "-";
          final reportId = job["damage_report_id"]?.toString() ??
              _getDamageReport(job)?["id"]?.toString() ??
              "-";

          final unitName = _getUnitName(job);
          final plateNumber = _getPlateNumber(job);
          final driverName = _getDriverName(job);
          final damageType = _getDamageType(job);

          final statusRaw = job["status"]?.toString() ?? "-";
          final status = _getStatusLabel(statusRaw);
          final statusColor = _getStatusColor(statusRaw);

          final scheduledAt = _formatDateTime(job["scheduled_at"]);
          final completedAt = _formatDateTime(job["completed_at"]);

          final repairDetails = _getRepairDetails(job);
          final hasKpi = _hasKpi(job);
          final isCompleted = _isCompleted(job);
          final isClosed = _isClosed(job);

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    unitName,
                    style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "#BK-$bookingId • #DR-$reportId",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Plate: $plateNumber",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Driver: $driverName",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduledAt == "-"
                              ? "Schedule: -"
                              : "Schedule: $scheduledAt",
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11,
                          ),
                        ),
                        if (completedAt != "-") ...[
                          const SizedBox(height: 2),
                          Text(
                            "Completed: $completedAt",
                            style: const TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: isCompleted
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        )
                      : Icon(
                          isClosed ? Icons.block : Icons.pending_actions,
                          color: statusColor,
                        ),
                ),
                const Divider(
                  color: Colors.white10,
                  indent: 16,
                  endIndent: 16,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Laporan Kerusakan Driver:",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.report_problem_outlined,
                        text: "Jenis: $damageType",
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Maintenance Details:",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...repairDetails.map<Widget>((detail) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildInfoRow(
                            icon: Icons.build,
                            text: detail,
                          ),
                        );
                      }),
                      if (isCompleted && !hasKpi) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF9A825),
                            ),
                            onPressed: () => _showKpiForm(context, job),
                            child: const Text(
                              "INPUT KPI",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFF9A825),
          size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Repair History",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}

// -------------------------------------------------------------------
// 2. MODAL INPUT KPI UNTUK JOB YANG SUDAH COMPLETED
// -------------------------------------------------------------------
class UpdateKpiModal extends StatefulWidget {
  final Map<String, dynamic> job;
  final String unitName;
  final Future<void> Function() onSuccess;

  const UpdateKpiModal({
    super.key,
    required this.job,
    required this.unitName,
    required this.onSuccess,
  });

  @override
  State<UpdateKpiModal> createState() => _UpdateKpiModalState();
}

class _UpdateKpiModalState extends State<UpdateKpiModal> {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  final TextEditingController _noteController = TextEditingController();

  final TextEditingController _repairTime = TextEditingController();
  final TextEditingController _failures = TextEditingController();
  final TextEditingController _opTime = TextEditingController();
  final TextEditingController _actualOp = TextEditingController();
  final TextEditingController _breakdown = TextEditingController();

  bool _isSubmitting = false;

  double mttr = 0;
  double mtbf = 0;
  double ma = 0;

  @override
  void initState() {
    super.initState();

    final existingNote = widget.job["note_technician"]?.toString();

    if (existingNote != null && existingNote.trim().isNotEmpty) {
      _noteController.text = existingNote;
    }

    mttr = double.tryParse(widget.job["mttr"]?.toString() ?? "") ?? 0;
    mtbf = double.tryParse(widget.job["mtbf"]?.toString() ?? "") ?? 0;
    ma = double.tryParse(widget.job["ma"]?.toString() ?? "") ?? 0;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _repairTime.dispose();
    _failures.dispose();
    _opTime.dispose();
    _actualOp.dispose();
    _breakdown.dispose();
    super.dispose();
  }

  int _getBookingId() {
    final rawId = widget.job["id"];

    if (rawId is int) return rawId;

    final parsed = int.tryParse(rawId?.toString() ?? "");

    if (parsed == null) {
      throw Exception("ID booking tidak valid.");
    }

    return parsed;
  }

  double _parseNumber(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(",", ".");
    return double.tryParse(value) ?? 0;
  }

  Map<String, double> _calculateKPIValue() {
    final double repairTime = _parseNumber(_repairTime);
    final double operationalTime = _parseNumber(_opTime);
    final double failures = _parseNumber(_failures);
    final double actualOperatingHours = _parseNumber(_actualOp);
    final double breakdownHours = _parseNumber(_breakdown);

    final double safeFailures = failures <= 0 ? 1.0 : failures;

    final double calculatedMttr = repairTime / safeFailures;
    final double calculatedMtbf = operationalTime / safeFailures;

    final double totalOperation = actualOperatingHours + breakdownHours;

    final double calculatedMa = totalOperation > 0
        ? (actualOperatingHours / totalOperation) * 100.0
        : 0.0;

    return {
      "mttr": calculatedMttr,
      "mtbf": calculatedMtbf,
      "ma": calculatedMa,
    };
  }

  void _previewKPI() {
    final kpi = _calculateKPIValue();

    setState(() {
      mttr = kpi["mttr"] ?? 0;
      mtbf = kpi["mtbf"] ?? 0;
      ma = kpi["ma"] ?? 0;
    });
  }

  Future<void> _submitKpi() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception("Token tidak ditemukan. Silakan login ulang.");
      }

      final bookingId = _getBookingId();

      final kpi = _calculateKPIValue();

      setState(() {
        mttr = kpi["mttr"] ?? 0;
        mtbf = kpi["mtbf"] ?? 0;
        ma = kpi["ma"] ?? 0;
      });

      final response = await http.post(
        Uri.parse("$baseUrl/technician/service-jobs/$bookingId/complete"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: {
          if (_noteController.text.trim().isNotEmpty)
            "note_technician": _noteController.text.trim(),
          "mttr": mttr.toStringAsFixed(2),
          "mtbf": mtbf.toStringAsFixed(2),
          "ma": ma.toStringAsFixed(1),
        },
      );

      debugPrint("KPI UPDATE STATUS: ${response.statusCode}");
      debugPrint("KPI UPDATE BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("KPI berhasil disimpan."),
            backgroundColor: Colors.green,
          ),
        );

        await widget.onSuccess();
      } else {
        throw Exception("Gagal menyimpan KPI: ${response.body}");
      }
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Input KPI: ${widget.unitName}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Catatan Teknisi",
                hintText: "Tambahkan catatan akhir maintenance...",
                hintStyle: const TextStyle(color: Colors.white24),
                labelStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white38),
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFF9A825)),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

            const SizedBox(height: 25),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),

            const Text(
              "KPI Analytics Calculation",
              style: TextStyle(
                color: Color(0xFFF9A825),
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            _input("Total Repair Time (Hours)", _repairTime),
            _input("Total Operational Time (Hours)", _opTime),
            _input("Number of Failures", _failures),
            _input("Actual Operating Hours", _actualOp),
            _input("Breakdown Hours", _breakdown),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: _previewKPI,
                child: const Text(
                  "PREVIEW KPI RESULTS",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 26),

            _resRow("MTTR:", "${mttr.toStringAsFixed(2)} hrs"),
            const SizedBox(height: 8),
            _resRow("MTBF:", "${mtbf.toStringAsFixed(2)} hrs"),
            const SizedBox(height: 8),
            _resRow("MA:", "${ma.toStringAsFixed(1)} %"),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                  disabledBackgroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitKpi,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "SAVE KPI",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white10,
          labelStyle: const TextStyle(
            color: Colors.white38,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white38),
            borderRadius: BorderRadius.circular(6),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFF9A825)),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _resRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9A825),
          ),
        ),
      ],
    );
  }
}