import 'package:flutter/material.dart';

class TaskDetailPage extends StatelessWidget {
  final String unitName;
  final String unitId;
  final String userRole;
  final VoidCallback? onUpdateStatus;

  /// Data dari backend:
  /// job['damage_report']?['part_usages']
  ///
  /// Contoh:
  /// [
  ///   {
  ///     "id": 1,
  ///     "qty": 2,
  ///     "status": "rejected",
  ///     "note": "[ADMIN-REJECT] Stok tidak tersedia",
  ///     "part": {
  ///       "name": "Filter Oli",
  ///       "sku": "FLT-001",
  ///       "stock": 0
  ///     }
  ///   }
  /// ]
  final List<Map<String, dynamic>> partUsages;

  /// Data dari backend:
  /// job['damage_report']?['part_usage_summary']
  ///
  /// Contoh:
  /// {
  ///   "total": 2,
  ///   "requested": 1,
  ///   "approved": 0,
  ///   "rejected": 1
  /// }
  final Map<String, dynamic>? partUsageSummary;

  /// Data dari backend:
  /// job['damage_report']?['has_rejected_part_usage']
  final bool? hasRejectedPartUsage;

  /// Data dari backend:
  /// job['damage_report']?['latest_rejected_part_usage_note']
  final String? latestRejectedPartUsageNote;

  const TaskDetailPage({
    super.key,
    required this.unitName,
    required this.unitId,
    required this.userRole,
    this.onUpdateStatus,
    this.partUsages = const <Map<String, dynamic>>[],
    this.partUsageSummary,
    this.hasRejectedPartUsage,
    this.latestRejectedPartUsageNote,
  });

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  bool get _isMechanic {
    final role = userRole.toUpperCase();
    return role == "MECHANIC" || role == "TEKNISI" || role == "TECHNICIAN";
  }

  bool get _isOperator {
    final role = userRole.toUpperCase();
    return role == "OPERATOR" || role == "DRIVER";
  }

  String get _roleLabel {
    final role = userRole.toUpperCase();

    if (role == "MECHANIC" || role == "TEKNISI" || role == "TECHNICIAN") {
      return "Mechanic";
    }

    if (role == "OPERATOR" || role == "DRIVER") {
      return "Operator";
    }

    return userRole;
  }

  Color get _roleColor {
    if (_isMechanic) {
      return Colors.lightBlueAccent;
    }

    if (_isOperator) {
      return Colors.greenAccent;
    }

    return Colors.white54;
  }

  bool get _hasRejectedPartUsage {
    if (hasRejectedPartUsage != null) {
      return hasRejectedPartUsage!;
    }

    return partUsages.any((usage) {
      final status = _normalizePartStatus(_textValue(usage['status']));
      return status == 'rejected';
    });
  }

  String get _latestRejectedNote {
    final backendNote = _cleanAdminNote(latestRejectedPartUsageNote ?? '');

    if (backendNote.isNotEmpty) {
      return backendNote;
    }

    for (final usage in partUsages) {
      final status = _normalizePartStatus(_textValue(usage['status']));

      if (status == 'rejected') {
        final note = _cleanAdminNote(_textValue(usage['note']));

        if (note.isNotEmpty) {
          return note;
        }
      }
    }

    return '';
  }

  void _handleUpdateStatus(BuildContext context) {
    if (onUpdateStatus != null) {
      onUpdateStatus!();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Fungsi update status belum dihubungkan."),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Detail Information",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
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
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            _isMechanic ? 110 : 30,
          ),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Unit Information",
              icon: Icons.local_shipping_outlined,
              child: Column(
                children: [
                  _buildInfoTile(
                    title: "Unit Name",
                    value: unitName,
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    title: "Unit ID",
                    value: unitId,
                    icon: Icons.confirmation_number_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    title: "User Role",
                    value: _roleLabel,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildSectionCard(
              title: "Task Flow",
              icon: Icons.account_tree_outlined,
              child: Column(
                children: [
                  _buildFlowItem(
                    title: "Task Received",
                    description: "Detail unit sudah berhasil dimuat.",
                    icon: Icons.assignment_turned_in_outlined,
                    color: Colors.greenAccent,
                    isLast: false,
                  ),
                  _buildFlowItem(
                    title: _isMechanic ? "Waiting for Action" : "View Only",
                    description: _isMechanic
                        ? "Mechanic dapat memperbarui status pekerjaan dan memantau progress permintaan sparepart."
                        : "Operator hanya dapat melihat informasi pekerjaan tanpa mengubah status.",
                    icon: _isMechanic
                        ? Icons.engineering_outlined
                        : Icons.visibility_outlined,
                    color: _isMechanic ? primaryColor : Colors.white54,
                    isLast: true,
                  ),
                ],
              ),
            ),

            if (_isMechanic) ...[
              const SizedBox(height: 16),
              _buildPartUsageSection(),
            ],

            const SizedBox(height: 16),

            if (!_isMechanic) _buildViewOnlyCard(),
          ],
        ),
      ),
      bottomNavigationBar: _isMechanic
          ? SafeArea(
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
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleUpdateStatus(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.update_rounded,
                      color: Colors.black,
                    ),
                    label: const Text(
                      "UPDATE STATUS",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
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
          _buildIconBadge(
            icon: _isMechanic
                ? Icons.engineering_rounded
                : Icons.visibility_rounded,
            color: _roleColor,
            size: 54,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unitName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unitId,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(_roleLabel, _roleColor),
                    _buildChip(
                      _isMechanic ? "Can Update" : "View Only",
                      _isMechanic ? primaryColor : Colors.white54,
                    ),
                    if (_isMechanic && _hasRejectedPartUsage)
                      _buildChip(
                        "Part Rejected",
                        Colors.redAccent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final color = _isMechanic ? primaryColor : Colors.lightBlueAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isMechanic
                  ? "Halaman ini digunakan mechanic untuk melihat detail unit, memperbarui status pekerjaan, dan memantau progress permintaan sparepart."
                  : "Halaman ini bersifat view-only. Operator hanya dapat melihat detail unit tanpa melakukan perubahan status.",
              style: const TextStyle(
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

  Widget _buildPartUsageSection() {
    return _buildSectionCard(
      title: "Sparepart Request Progress",
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          _buildPartUsageSummaryCard(),

          if (_hasRejectedPartUsage) ...[
            const SizedBox(height: 12),
            _buildRejectedAlertCard(),
          ],

          const SizedBox(height: 12),

          if (partUsages.isEmpty)
            _buildEmptyPartUsageCard()
          else
            Column(
              children: [
                for (int i = 0; i < partUsages.length; i++) ...[
                  _buildPartUsageCard(partUsages[i]),
                  if (i != partUsages.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPartUsageSummaryCard() {
    final total = _summaryValue('total');
    final requested = _summaryValue('requested');
    final approved = _summaryValue('approved');
    final rejected = _summaryValue('rejected');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              label: "Total",
              value: total.toString(),
              color: Colors.white70,
              icon: Icons.inventory_2_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItem(
              label: "Pending",
              value: requested.toString(),
              color: primaryColor,
              icon: Icons.pending_actions_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItem(
              label: "Approved",
              value: approved.toString(),
              color: Colors.greenAccent,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryItem(
              label: "Rejected",
              value: rejected.toString(),
              color: Colors.redAccent,
              icon: Icons.cancel_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.16),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 17,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedAlertCard() {
    final note = _latestRejectedNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withOpacity(0.16),
            Colors.redAccent.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note.isEmpty
                  ? "Terdapat permintaan sparepart yang ditolak admin. Silakan cek daftar request di bawah untuk melihat detailnya."
                  : "Terdapat permintaan sparepart yang ditolak admin.\nAlasan: $note",
              style: const TextStyle(
                color: Colors.white70,
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

  Widget _buildEmptyPartUsageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.white38,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Belum ada permintaan sparepart untuk pekerjaan ini.",
              style: TextStyle(
                color: Colors.white54,
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

  Widget _buildPartUsageCard(Map<String, dynamic> usage) {
    final rawStatus = _textValue(usage['status']);
    final status = _normalizePartStatus(rawStatus);
    final qty = _textValue(usage['qty']);
    final note = _cleanAdminNote(_textValue(usage['note']));

    final partName = _partName(usage);
    final sku = _partSku(usage);
    final stock = _partStock(usage);

    final statusColor = _partStatusColor(status);
    final statusIcon = _partStatusIcon(status);
    final statusLabel = _partStatusLabel(status);
    final statusDescription = _partStatusDescription(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.12),
            Colors.white.withOpacity(0.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withOpacity(0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(
            icon: statusIcon,
            color: statusColor,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSmallStatusChip(statusLabel, statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "SKU: $sku • Qty: ${qty.isEmpty ? "-" : qty} • Stock: $stock",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusDescription,
                  style: TextStyle(
                    color: statusColor.withOpacity(0.92),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildAdminNoteBox(
                    status: status,
                    note: note,
                    color: statusColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNoteBox({
    required String status,
    required String note,
    required Color color,
  }) {
    final title = status == "rejected"
        ? "Alasan Penolakan Admin"
        : "Catatan Admin";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withOpacity(0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notes_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$title\n",
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: note,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _summaryValue(String key) {
    if (partUsageSummary != null) {
      dynamic value = partUsageSummary![key];

      if (value == null && key == 'requested') {
        value = partUsageSummary!['pending'];
      }

      final parsed = _intValue(value);

      if (parsed != null) {
        return parsed;
      }
    }

    if (key == 'total') {
      return partUsages.length;
    }

    int count = 0;

    for (final usage in partUsages) {
      final status = _normalizePartStatus(_textValue(usage['status']));

      if (key == 'requested' && status == 'requested') {
        count++;
      }

      if (key == 'approved' && status == 'approved') {
        count++;
      }

      if (key == 'rejected' && status == 'rejected') {
        count++;
      }
    }

    return count;
  }

  String _partName(Map<String, dynamic> usage) {
    final part = usage['part'];

    if (part is Map) {
      final name = _textValue(part['name']);
      return name.isEmpty ? "-" : name;
    }

    final name = _textValue(usage['part_name']);
    return name.isEmpty ? "-" : name;
  }

  String _partSku(Map<String, dynamic> usage) {
    final part = usage['part'];

    if (part is Map) {
      final sku = _textValue(part['sku']);
      return sku.isEmpty ? "-" : sku;
    }

    final sku = _textValue(usage['sku']);
    return sku.isEmpty ? "-" : sku;
  }

  String _partStock(Map<String, dynamic> usage) {
    final part = usage['part'];

    if (part is Map) {
      final stock = _textValue(part['stock']);
      return stock.isEmpty ? "-" : stock;
    }

    final stock = _textValue(usage['stock']);
    return stock.isEmpty ? "-" : stock;
  }

  String _normalizePartStatus(String status) {
    final value = status.toLowerCase().trim().replaceAll("-", "_");

    switch (value) {
      case "approved":
      case "approve":
      case "disetujui":
        return "approved";

      case "rejected":
      case "reject":
      case "ditolak":
        return "rejected";

      case "pending":
      case "requested":
      case "request":
      case "menunggu":
        return "requested";

      default:
        return value.isEmpty ? "requested" : value;
    }
  }

  Color _partStatusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.greenAccent;
      case "rejected":
        return Colors.redAccent;
      case "requested":
        return primaryColor;
      default:
        return Colors.lightBlueAccent;
    }
  }

  IconData _partStatusIcon(String status) {
    switch (status) {
      case "approved":
        return Icons.check_circle_outline_rounded;
      case "rejected":
        return Icons.cancel_outlined;
      case "requested":
        return Icons.pending_actions_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _partStatusLabel(String status) {
    switch (status) {
      case "approved":
        return "Approved";
      case "rejected":
        return "Rejected";
      case "requested":
        return "Pending";
      default:
        return status.isEmpty ? "Unknown" : status;
    }
  }

  String _partStatusDescription(String status) {
    switch (status) {
      case "approved":
        return "Permintaan sparepart telah disetujui admin dan dapat digunakan untuk proses perbaikan.";
      case "rejected":
        return "Permintaan sparepart ditolak admin. Periksa catatan admin untuk mengetahui alasannya.";
      case "requested":
        return "Permintaan sparepart sedang menunggu persetujuan admin.";
      default:
        return "Status permintaan sparepart belum dikenali oleh sistem.";
    }
  }

  String _textValue(dynamic value) {
    if (value == null) return "";
    return value.toString().trim();
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    final parsed = int.tryParse(value.toString());

    return parsed;
  }

  String _cleanAdminNote(String note) {
    return note
        .replaceAll("[ADMIN-REJECT]", "")
        .replaceAll("[ADMIN]", "")
        .replaceAll("[ADMIN APPROVE]", "")
        .replaceAll("[ADMIN-APPROVE]", "")
        .trim();
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
          _buildSectionTitle(title, icon),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.05,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.052),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          _buildIconBadge(
            icon: icon,
            color: primaryColor,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty ? "-" : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowItem({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.35),
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withOpacity(0.10),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewOnlyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: Colors.white38,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Mode View-Only. Operator dapat melihat detail informasi unit, tetapi tidak dapat memperbarui status pekerjaan.",
              style: TextStyle(
                color: Colors.white54,
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

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.3),
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

  Widget _buildSmallStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.32),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildIconBadge({
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
}