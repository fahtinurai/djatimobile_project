import 'package:flutter/material.dart';

class TaskDetailPage extends StatelessWidget {
  final String unitName;
  final String unitId;
  final String userRole;

  /// Data dari backend, opsional.
  ///
  /// Bisa berupa:
  /// 1. damage report langsung
  /// 2. service booking yang punya damage_report
  /// 3. data gabungan dari booking/admin/technician endpoint
  final Map<String, dynamic>? report;

  /// Optional action kalau tombol UPDATE STATUS / ACTION ditekan.
  final VoidCallback? onUpdateStatus;

  const TaskDetailPage({
    super.key,
    this.unitName = "Unit",
    this.unitId = "#ID",
    required this.userRole,
    this.report,
    this.onUpdateStatus,
  });

  // =========================================================
  // DATA NORMALIZER
  // =========================================================

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  /// Kalau data yang masuk adalah ServiceBooking, biasanya punya damage_report.
  /// Kalau data yang masuk langsung DamageReport, maka pakai report langsung.
  Map<String, dynamic>? _getDamageReport() {
    final nested = _asMap(report?["damage_report"]);

    if (nested != null) {
      return nested;
    }

    return report;
  }

  /// Data booking.
  ///
  /// Bisa:
  /// - report langsung adalah booking
  /// - report punya key service_booking
  /// - report punya key booking
  Map<String, dynamic>? _getBooking() {
    final serviceBooking = _asMap(report?["service_booking"]);
    if (serviceBooking != null) {
      return serviceBooking;
    }

    final booking = _asMap(report?["booking"]);
    if (booking != null) {
      return booking;
    }

    final hasBookingFields = report?["scheduled_at"] != null ||
        report?["preferred_at"] != null ||
        report?["estimated_finish_at"] != null ||
        report?["requested_at"] != null ||
        report?["damage_report"] != null;

    if (hasBookingFields) {
      return report;
    }

    return null;
  }

  Map<String, dynamic>? _getVehicle() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingVehicle = _asMap(booking?["vehicle"]);
    if (bookingVehicle != null) {
      return bookingVehicle;
    }

    final reportVehicle = _asMap(damageReport?["vehicle"]);
    if (reportVehicle != null) {
      return reportVehicle;
    }

    final directVehicle = _asMap(report?["vehicle"]);
    if (directVehicle != null) {
      return directVehicle;
    }

    return null;
  }

  Map<String, dynamic>? _getDriver() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingDriver = _asMap(booking?["driver"]);
    if (bookingDriver != null) {
      return bookingDriver;
    }

    final reportDriver = _asMap(damageReport?["driver"]);
    if (reportDriver != null) {
      return reportDriver;
    }

    final directDriver = _asMap(report?["driver"]);
    if (directDriver != null) {
      return directDriver;
    }

    return null;
  }

  Map<String, dynamic>? _getTechnician() {
    final booking = _getBooking();

    final technician = _asMap(booking?["technician"]);
    if (technician != null) {
      return technician;
    }

    final mechanic = _asMap(booking?["mechanic"]);
    if (mechanic != null) {
      return mechanic;
    }

    final user = _asMap(booking?["user"]);
    if (user != null) {
      return user;
    }

    return null;
  }

  // =========================================================
  // BASIC INFO
  // =========================================================

  String _getUnitName() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["equipment_name"]?.toString() ??
          vehicle["name"]?.toString() ??
          unitName;
    }

    final damageReport = _getDamageReport();

    return damageReport?["equipment_name"]?.toString() ??
        report?["equipment_name"]?.toString() ??
        unitName;
  }

  String _getUnitId() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    final bookingId = booking?["id"]?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      return "#BK-$bookingId";
    }

    final reportId = damageReport?["id"]?.toString();
    if (reportId != null && reportId.isNotEmpty) {
      return "#DR-$reportId";
    }

    return unitId;
  }

  String _getReportId() {
    final damageReport = _getDamageReport();

    final id = damageReport?["id"]?.toString();
    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#DR-$id";
  }

  String _getBookingId() {
    final booking = _getBooking();

    final id = booking?["id"]?.toString();
    if (id == null || id.isEmpty) {
      return "-";
    }

    return "#BK-$id";
  }

  String _getPlateNumber() {
    final vehicle = _getVehicle();

    if (vehicle != null) {
      return vehicle["plate_number"]?.toString() ?? "-";
    }

    return "-";
  }

  String _getDriverName() {
    final driver = _getDriver();

    if (driver != null) {
      return driver["name"]?.toString() ??
          driver["username"]?.toString() ??
          "Unknown Driver";
    }

    return "Unknown Driver";
  }

  String _getTechnicianName() {
    final technician = _getTechnician();

    if (technician != null) {
      return technician["name"]?.toString() ??
          technician["username"]?.toString() ??
          "Assigned";
    }

    return "Belum ditugaskan";
  }

  String _getDamageType() {
    final damageReport = _getDamageReport();

    return damageReport?["damage_type"]?.toString() ??
        report?["damage_type"]?.toString() ??
        "-";
  }

  String _getDescription() {
    final damageReport = _getDamageReport();

    return damageReport?["description"]?.toString() ??
        damageReport?["note"]?.toString() ??
        report?["description"]?.toString() ??
        "Unit requires immediate attention.";
  }

  String _getNoteDriver() {
    final booking = _getBooking();

    return booking?["note_driver"]?.toString() ?? "-";
  }

  String _getNoteAdmin() {
    final booking = _getBooking();

    return booking?["note_admin"]?.toString() ?? "-";
  }

  String _getPriority() {
    final booking = _getBooking();

    return booking?["priority"]?.toString() ?? "-";
  }

  // =========================================================
  // DATE FORMATTER
  // =========================================================

  String _formatDateTime(dynamic rawValue) {
    final raw = rawValue?.toString();

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

      return "$day-$month-$year $hour:$minute";
    } catch (_) {
      return raw;
    }
  }

  String _getCreatedAt() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();

    return _formatDateTime(
      booking?["created_at"] ??
          booking?["requested_at"] ??
          damageReport?["created_at"] ??
          report?["created_at"],
    );
  }

  String _getPreferredAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["preferred_at"]);
  }

  String _getScheduledAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["scheduled_at"]);
  }

  String _getEstimatedFinishAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["estimated_finish_at"]);
  }

  String _getStartedAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["started_at"]);
  }

  String _getCompletedAt() {
    final booking = _getBooking();

    return _formatDateTime(booking?["completed_at"]);
  }

  // =========================================================
  // STATUS
  // =========================================================

  Map<String, dynamic>? _getLatestResponse() {
    final damageReport = _getDamageReport();

    final latest = _asMap(damageReport?["latest_technician_response"]);
    if (latest != null) {
      return latest;
    }

    final directLatest = _asMap(report?["latest_technician_response"]);
    if (directLatest != null) {
      return directLatest;
    }

    return null;
  }

  String _getRawStatus() {
    final booking = _getBooking();
    final damageReport = _getDamageReport();
    final latest = _getLatestResponse();

    return booking?["status"]?.toString() ??
        damageReport?["status"]?.toString() ??
        latest?["status"]?.toString() ??
        report?["status"]?.toString() ??
        "reported";
  }

  String _getStatus() {
    final status = _getRawStatus().toLowerCase();

    switch (status) {
      case "requested":
      case "pending":
      case "menunggu":
      case "reported":
        return "Requested";

      case "approved":
      case "scheduled":
        return "Approved";

      case "rescheduled":
        return "Rescheduled";

      case "proses":
      case "diproses":
      case "ongoing":
      case "in_progress":
        return "In Progress";

      case "butuh_followup_admin":
      case "menunggu_sparepart":
      case "waiting_parts":
      case "on hold":
        return "On Hold";

      case "selesai":
      case "finished":
      case "completed":
        return "Completed";

      case "canceled":
      case "cancelled":
      case "dibatalkan":
        return "Canceled";

      case "rejected":
      case "ditolak":
        return "Rejected";

      case "fatal":
        return "Fatal";

      default:
        return _getRawStatus();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "requested":
        return Colors.orange;

      case "approved":
        return Colors.lightBlueAccent;

      case "rescheduled":
        return Colors.purpleAccent;

      case "in progress":
        return Colors.blue;

      case "on hold":
        return Colors.redAccent;

      case "completed":
        return Colors.green;

      case "canceled":
        return Colors.grey;

      case "rejected":
        return Colors.redAccent;

      case "fatal":
        return Colors.red;

      default:
        return Colors.white54;
    }
  }

  String _getStatusDescription() {
    final status = _getStatus().toLowerCase();

    switch (status) {
      case "requested":
        return "Booking maintenance sudah diajukan oleh driver dan menunggu approval admin.";

      case "approved":
        return "Booking sudah disetujui admin. Teknisi dapat mulai mengerjakan sesuai jadwal.";

      case "rescheduled":
        return "Jadwal maintenance telah diubah oleh admin.";

      case "in progress":
        return "Teknisi sedang mengerjakan maintenance kendaraan.";

      case "on hold":
        return "Pekerjaan tertunda dan membutuhkan tindak lanjut.";

      case "completed":
        return "Maintenance telah selesai dikerjakan.";

      case "canceled":
        return "Booking maintenance telah dibatalkan.";

      case "rejected":
        return "Booking atau laporan ditolak.";

      default:
        return "Status maintenance sedang diperbarui.";
    }
  }

  String _getTechnicianNote() {
    final latest = _getLatestResponse();

    if (latest != null) {
      return latest["note"]?.toString() ??
          latest["response_note"]?.toString() ??
          "-";
    }

    final booking = _getBooking();

    return booking?["note_technician"]?.toString() ??
        "Belum ada catatan teknisi.";
  }

  bool get _isMechanic {
    final role = userRole.toUpperCase();

    return role == "MECHANIC" ||
        role == "TEKNISI" ||
        role == "TECHNICIAN";
  }

  bool get _isAdmin {
    return userRole.toUpperCase() == "ADMIN";
  }

  bool get _isDriver {
    return userRole.toUpperCase() == "DRIVER" ||
        userRole.toUpperCase() == "OPERATOR";
  }

  bool get _isFinished {
    final status = _getStatus().toLowerCase();

    return status == "completed" ||
        status == "finished" ||
        status == "canceled" ||
        status == "rejected";
  }

  bool get _canShowActionButton {
    return (_isMechanic || _isAdmin) && onUpdateStatus != null;
  }

  String _getActionButtonText() {
    final status = _getStatus().toLowerCase();

    if (_isAdmin) {
      if (status == "requested") {
        return "APPROVE / SCHEDULE";
      }

      if (status == "approved" || status == "rescheduled") {
        return "RESCHEDULE / CANCEL";
      }

      return "UPDATE BOOKING";
    }

    if (_isMechanic) {
      if (status == "approved" || status == "rescheduled") {
        return "START JOB";
      }

      if (status == "in progress") {
        return "COMPLETE JOB";
      }

      if (_isFinished) {
        return "TASK COMPLETED";
      }

      return "UPDATE STATUS";
    }

    return "UPDATE STATUS";
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final unit = _getUnitName();
    final id = _getUnitId();
    final status = _getStatus();
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Detail Information",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          _canShowActionButton ? 110 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unit,
              style: const TextStyle(
                color: Color(0xFFF9A825),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              id,
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildStatusInfoCard(statusColor),

            const SizedBox(height: 30),

            Row(
              children: [
                _buildInfoBox("DATE", _getCreatedAt()),
                const SizedBox(width: 16),
                _buildInfoBox("PLATE", _getPlateNumber()),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _buildInfoBox("DRIVER", _getDriverName()),
                const SizedBox(width: 16),
                _buildInfoBox("DAMAGE", _getDamageType()),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _buildInfoBox("REPORT ID", _getReportId()),
                const SizedBox(width: 16),
                _buildInfoBox("BOOKING ID", _getBookingId()),
              ],
            ),

            const SizedBox(height: 30),

            _buildSectionTitle("MAINTENANCE SCHEDULE"),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildInfoBox("PREFERRED", _getPreferredAt()),
                const SizedBox(width: 16),
                _buildInfoBox("SCHEDULED", _getScheduledAt()),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _buildInfoBox("EST. FINISH", _getEstimatedFinishAt()),
                const SizedBox(width: 16),
                _buildInfoBox("TECHNICIAN", _getTechnicianName()),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _buildInfoBox("STARTED", _getStartedAt()),
                const SizedBox(width: 16),
                _buildInfoBox("COMPLETED", _getCompletedAt()),
              ],
            ),

            const SizedBox(height: 30),

            _buildSectionTitle("REPORT DETAILS"),
            const SizedBox(height: 10),

            _buildTextCard(_getDescription()),

            const SizedBox(height: 24),

            _buildSectionTitle("DRIVER NOTE"),
            const SizedBox(height: 10),
            _buildTextCard(_getNoteDriver()),

            const SizedBox(height: 24),

            _buildSectionTitle("ADMIN NOTE"),
            const SizedBox(height: 10),
            _buildTextCard(_getNoteAdmin()),

            const SizedBox(height: 24),

            _buildSectionTitle("TECHNICIAN NOTE"),
            const SizedBox(height: 10),
            _buildTextCard(_getTechnicianNote(), highlight: true),

            const SizedBox(height: 24),

            Row(
              children: [
                _buildInfoBox("PRIORITY", _getPriority()),
                const SizedBox(width: 16),
                _buildInfoBox("VIEW AS", userRole.toUpperCase()),
              ],
            ),

            const SizedBox(height: 30),

            if (_isDriver)
              const Center(
                child: Text(
                  "Driver dapat memantau status booking setelah admin menjadwalkan teknisi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),

            if (!_isDriver && !_isMechanic && !_isAdmin)
              const Center(
                child: Text(
                  "Viewing mode only",
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _canShowActionButton
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                color: const Color(0xFF121212),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isFinished ? null : onUpdateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9A825),
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _isFinished ? "TASK CLOSED" : _getActionButtonText(),
                      style: TextStyle(
                        color: _isFinished ? Colors.white38 : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatusInfoCard(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _getStatusDescription(),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFF9A825),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextCard(String value, {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? Colors.white10 : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Text(
        value.isEmpty ? "-" : value,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.isEmpty ? "-" : value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}