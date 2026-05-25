import 'package:flutter/material.dart';
import 'package:djatimobile_project/core/services/service_booking_service.dart';

class DriverServiceBookingPage extends StatefulWidget {
  const DriverServiceBookingPage({super.key});

  @override
  State<DriverServiceBookingPage> createState() =>
      _DriverServiceBookingPageState();
}

class _DriverServiceBookingPageState extends State<DriverServiceBookingPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookings = await ServiceBookingService.getMyBookings();

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
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

  Map<String, dynamic>? _getDamageReport(Map<String, dynamic> booking) {
    final report = _asMap(booking["damage_report"]);

    if (report != null) {
      return report;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle(Map<String, dynamic> booking) {
    final directVehicle = _asMap(booking["vehicle"]);
    if (directVehicle != null) {
      return directVehicle;
    }

    final report = _getDamageReport(booking);
    final reportVehicle = _asMap(report?["vehicle"]);

    if (reportVehicle != null) {
      return reportVehicle;
    }

    return null;
  }

  Map<String, dynamic>? _getDriver(Map<String, dynamic> booking) {
    final directDriver = _asMap(booking["driver"]);
    if (directDriver != null) {
      return directDriver;
    }

    final report = _getDamageReport(booking);
    final reportDriver = _asMap(report?["driver"]);

    if (reportDriver != null) {
      return reportDriver;
    }

    return null;
  }

  Map<String, dynamic>? _getTechnician(Map<String, dynamic> booking) {
    final technician = _asMap(booking["technician"]);
    if (technician != null) {
      return technician;
    }

    final mechanic = _asMap(booking["mechanic"]);
    if (mechanic != null) {
      return mechanic;
    }

    final assignedTechnician = _asMap(booking["assigned_technician"]);
    if (assignedTechnician != null) {
      return assignedTechnician;
    }

    return null;
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

  String _getUnitName(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          "Unknown Unit";
    }

    final report = _getDamageReport(booking);

    return report?["equipment_name"]?.toString() ?? "Unknown Unit";
  }

  String _getPlateNumber(Map<String, dynamic> booking) {
    final vehicle = _getVehicle(booking);

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDamageType(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    return report?["damage_type"]?.toString() ??
        booking["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    return report?["description"]?.toString() ??
        booking["description"]?.toString() ??
        "-";
  }

  String _getDriverName(Map<String, dynamic> booking) {
    final driver = _getDriver(booking);

    if (driver == null) {
      return "-";
    }

    return driver["name"]?.toString() ??
        driver["username"]?.toString() ??
        "-";
  }

  String _getTechnicianName(Map<String, dynamic> booking) {
    final technician = _getTechnician(booking);

    if (technician == null) {
      return "Belum ditugaskan";
    }

    return technician["name"]?.toString() ??
        technician["username"]?.toString() ??
        "Teknisi";
  }

  String _getBookingId(Map<String, dynamic> booking) {
    final id = booking["id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#BK-$id";
  }

  String _getReportId(Map<String, dynamic> booking) {
    final report = _getDamageReport(booking);

    final id = report?["id"]?.toString() ?? booking["damage_report_id"]?.toString();

    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#DR-$id";
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return "Waiting Admin Schedule";

      case "approved":
      case "scheduled":
        return "Scheduled";

      case "rescheduled":
        return "Rescheduled";

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return "In Progress";

      case "completed":
      case "finished":
      case "selesai":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "rejected":
      case "ditolak":
        return "Rejected";

      default:
        return status;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return "Booking maintenance sudah diajukan dan sedang menunggu admin menentukan jadwal serta teknisi.";

      case "approved":
      case "scheduled":
        return "Admin sudah menyetujui booking dan menentukan jadwal maintenance.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "completed":
      case "finished":
      case "selesai":
        return "Maintenance kendaraan sudah selesai dikerjakan.";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
      case "ditolak":
        return "Booking maintenance ditolak.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "requested":
      case "pending":
      case "reported":
      case "menunggu":
        return Colors.orange;

      case "approved":
      case "scheduled":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in_progress":
      case "ongoing":
      case "proses":
      case "diproses":
        return Colors.amber;

      case "completed":
      case "finished":
      case "selesai":
        return Colors.green;

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return Colors.redAccent;

      case "rejected":
      case "ditolak":
        return Colors.redAccent;

      default:
        return Colors.white54;
    }
  }

  bool _canCancelBooking(String status) {
    final lowerStatus = status.toLowerCase();

    return lowerStatus == "requested" ||
        lowerStatus == "approved" ||
        lowerStatus == "rescheduled";
  }

  Future<void> _confirmCancelBooking(Map<String, dynamic> booking) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Batalkan Booking?",
            style: TextStyle(color: Color(0xFFF9A825)),
          ),
          content: const Text(
            "Booking maintenance akan dibatalkan. Jika kerusakan masih perlu ditangani, kamu dapat mengajukan ulang dari laporan yang sama selama backend mengizinkan.",
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Ya, Batalkan",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _cancelBooking(booking);
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final bookingId = int.tryParse(booking["id"]?.toString() ?? "");

    if (bookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ID booking tidak valid."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final status = booking["status"]?.toString().toLowerCase() ?? "";

    if (!_canCancelBooking(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking ini tidak bisa dibatalkan."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ServiceBookingService.cancelBooking(bookingId: bookingId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking berhasil dibatalkan."),
          backgroundColor: Colors.green,
        ),
      );

      _loadBookings();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<String> _getTimelineLogs(Map<String, dynamic> booking) {
    final logs = <String>[];

    final damageType = _getDamageType(booking);
    final description = _getDescription(booking);
    final preferredAt = _formatDateTime(booking["preferred_at"]);
    final requestedAt = _formatDateTime(
      booking["requested_at"] ?? booking["created_at"],
    );
    final scheduledAt = _formatDateTime(booking["scheduled_at"]);
    final estimatedFinishAt = _formatDateTime(booking["estimated_finish_at"]);
    final startedAt = _formatDateTime(booking["started_at"]);
    final completedAt = _formatDateTime(booking["completed_at"]);

    final noteDriver = booking["note_driver"]?.toString() ?? "-";
    final noteAdmin = booking["note_admin"]?.toString() ?? "-";
    final noteTechnician = booking["note_technician"]?.toString() ?? "-";

    final technicianName = _getTechnicianName(booking);
    final statusLabel = _getStatusLabel(
      booking["status"]?.toString() ?? "requested",
    );

    if (damageType != "-") {
      logs.add("Laporan kerusakan: $damageType");
    }

    if (description != "-") {
      logs.add("Deskripsi: $description");
    }

    if (requestedAt != "-") {
      logs.add("Booking diajukan pada: $requestedAt");
    }

    if (preferredAt != "-") {
      logs.add("Preferensi jadwal driver: $preferredAt");
    }

    if (noteDriver != "-") {
      logs.add("Catatan driver: $noteDriver");
    }

    if (scheduledAt != "-") {
      logs.add("Jadwal final admin: $scheduledAt");
    } else {
      logs.add("Menunggu admin menentukan jadwal final.");
    }

    if (estimatedFinishAt != "-") {
      logs.add("Estimasi selesai: $estimatedFinishAt");
    }

    if (noteAdmin != "-") {
      logs.add("Catatan admin: $noteAdmin");
    }

    if (technicianName != "Belum ditugaskan") {
      logs.add("Teknisi ditugaskan: $technicianName");
    } else {
      logs.add("Menunggu admin menugaskan teknisi.");
    }

    if (startedAt != "-") {
      logs.add("Teknisi mulai kerja pada: $startedAt");
    }

    if (completedAt != "-") {
      logs.add("Maintenance selesai pada: $completedAt");
    }

    if (noteTechnician != "-") {
      logs.add("Catatan teknisi: $noteTechnician");
    }

    logs.add("Status saat ini: $statusLabel");

    return logs;
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
                onPressed: _loadBookings,
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

    if (_bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBookings,
        color: const Color(0xFFF9A825),
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.calendar_month_outlined,
              color: Colors.white24,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada booking maintenance.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 8),
            Text(
              "Booking akan muncul setelah kamu membuat laporan kerusakan dan sistem mengajukannya ke admin.",
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
      onRefresh: _loadBookings,
      color: const Color(0xFFF9A825),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Maintenance Scheduling",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            "Pantau booking dari request driver, approval admin, sampai teknisi menyelesaikan pekerjaan.",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ..._bookings.map<Widget>((item) {
            final booking = Map<String, dynamic>.from(item as Map);
            return _buildBookingCard(booking);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final unitName = _getUnitName(booking);
    final plateNumber = _getPlateNumber(booking);
    final damageType = _getDamageType(booking);
    final description = _getDescription(booking);

    final status = booking["status"]?.toString() ?? "requested";
    final priority = booking["priority"]?.toString() ?? "medium";

    final preferredAt = _formatDateTime(booking["preferred_at"]);
    final scheduledAt = _formatDateTime(booking["scheduled_at"]);
    final estimatedFinishAt = _formatDateTime(booking["estimated_finish_at"]);
    final startedAt = _formatDateTime(booking["started_at"]);
    final completedAt = _formatDateTime(booking["completed_at"]);

    final noteDriver = booking["note_driver"]?.toString() ?? "-";
    final noteAdmin = booking["note_admin"]?.toString() ?? "-";
    final noteTechnician = booking["note_technician"]?.toString() ?? "-";

    final technicianName = _getTechnicianName(booking);
    final driverName = _getDriverName(booking);

    final color = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);
    final canCancel = _canCancelBooking(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedIconColor: Colors.white38,
        iconColor: const Color(0xFFF9A825),
        title: Text(
          unitName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF9A825),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Plate Number: $plateNumber",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "${_getReportId(booking)}  •  ${_getBookingId(booking)}",
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _statusChip(statusLabel, color),
                  _miniChip("Priority: $priority"),
                ],
              ),
            ],
          ),
        ),
        children: [
          _statusInfoCard(status, color),
          const SizedBox(height: 14),

          _infoRow("Damage Type", damageType),
          const SizedBox(height: 8),
          _infoRow("Description", description),
          const SizedBox(height: 8),
          _infoRow("Driver", driverName),

          const Divider(color: Colors.white10, height: 28),

          _sectionTitle("Schedule"),
          const SizedBox(height: 10),
          _infoRow("Preferred At", preferredAt),
          const SizedBox(height: 8),
          _infoRow(
            "Scheduled At",
            scheduledAt == "-" ? "Menunggu admin" : scheduledAt,
          ),
          const SizedBox(height: 8),
          _infoRow("Finish Est.", estimatedFinishAt),
          const SizedBox(height: 8),
          _infoRow("Technician", technicianName),
          const SizedBox(height: 8),
          _infoRow("Started At", startedAt),
          const SizedBox(height: 8),
          _infoRow("Completed At", completedAt),

          const Divider(color: Colors.white10, height: 28),

          _sectionTitle("Notes"),
          const SizedBox(height: 10),
          _infoRow("Driver Note", noteDriver),
          const SizedBox(height: 8),
          _infoRow("Admin Note", noteAdmin),
          const SizedBox(height: 8),
          _infoRow("Tech Note", noteTechnician),

          const Divider(color: Colors.white10, height: 28),

          _sectionTitle("Timeline"),
          const SizedBox(height: 10),
          ..._getTimelineLogs(booking).map(
            (log) => _timelineItem(log, color),
          ),

          if (canCancel) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _confirmCancelBooking(booking),
                child: const Text(
                  "CANCEL BOOKING",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusInfoCard(String status, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getStatusDescription(status),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Text(
      value.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFF9A825),
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _timelineItem(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: color.withOpacity(0.85),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? "-" : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
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
        title: const Text(
          "Maintenance Schedule",
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