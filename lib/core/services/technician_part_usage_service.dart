import 'package:djatimobile_project/core/services/api_service.dart';

class TechnicianPartUsageService {
  // ---------------------------------------------------------------------------
  // PARTS
  // ---------------------------------------------------------------------------

  /// Ambil daftar sparepart untuk dipilih teknisi.
  ///
  /// Backend:
  /// GET /api/technician/parts
  /// GET /api/technician/parts?search=...
  static Future<List<dynamic>> getParts({
    String search = "",
  }) async {
    final endpoint = search.trim().isEmpty
        ? "/technician/parts"
        : "/technician/parts?search=${Uri.encodeQueryComponent(search.trim())}";

    final result = await ApiService.get(endpoint);

    final statusCode = result["statusCode"];
    final data = result["data"];

    if (statusCode == 200) {
      final list = _extractList(data);

      return _normalizePartList(list);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        "Gagal mengambil daftar sparepart.",
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REQUEST PART USAGE
  // ---------------------------------------------------------------------------

  /// Teknisi request sparepart.
  ///
  /// Backend:
  /// POST /api/technician/part-usages
  ///
  /// Body:
  /// {
  ///   "part_id": 1,
  ///   "damage_report_id": 5,
  ///   "service_booking_id": 9,
  ///   "booking_id": 9,
  ///   "qty": 2,
  ///   "note": "Catatan"
  /// }
  ///
  /// Catatan:
  /// - damage_report_id tetap wajib karena backend menyimpan request
  ///   berdasarkan damage report.
  /// - service_booking_id / booking_id tetap dikirim untuk kompatibilitas
  ///   dengan flow job teknisi.
  static Future<Map<String, dynamic>> requestPartUsage({
    required int partId,
    required int damageReportId,
    int? serviceBookingId,
    int? bookingId,
    required int qty,
    String? note,
  }) async {
    if (partId <= 0) {
      throw Exception("Sparepart wajib dipilih.");
    }

    if (damageReportId <= 0) {
      throw Exception("Damage report ID tidak valid.");
    }

    final resolvedBookingId = serviceBookingId ?? bookingId;

    if (qty < 1) {
      throw Exception("Qty minimal 1.");
    }

    final body = <String, dynamic>{
      "part_id": partId,
      "damage_report_id": damageReportId,
      if (resolvedBookingId != null && resolvedBookingId > 0)
        "service_booking_id": resolvedBookingId,
      if (resolvedBookingId != null && resolvedBookingId > 0)
        "booking_id": resolvedBookingId,
      "qty": qty,
      if (note != null && note.trim().isNotEmpty) "note": note.trim(),
    };

    final result = await ApiService.post(
      "/technician/part-usages",
      body,
    );

    final statusCode = result["statusCode"];
    final data = result["data"];

    if (statusCode == 200 || statusCode == 201) {
      final mapped = _extractMap(data);

      if (mapped != null) {
        return _normalizePartUsage(mapped);
      }

      return {
        "message": "Request sparepart berhasil dikirim.",
        "data": data,
      };
    }

    throw Exception(
      _extractErrorMessage(
        data,
        "Gagal mengirim request sparepart.",
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MY PART USAGES
  // ---------------------------------------------------------------------------

  /// Riwayat request sparepart teknisi login.
  ///
  /// Backend:
  /// GET /api/technician/my-part-usages
  ///
  /// Response bisa berisi status:
  /// - requested / pending
  /// - approved
  /// - rejected
  static Future<List<dynamic>> getMyPartUsages() async {
    final result = await ApiService.get(
      "/technician/my-part-usages",
    );

    final statusCode = result["statusCode"];
    final data = result["data"];

    if (statusCode == 200) {
      final list = _extractList(data);

      return _normalizePartUsageList(list);
    }

    throw Exception(
      _extractErrorMessage(
        data,
        "Gagal mengambil riwayat request sparepart.",
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // JOB DETAIL / DAMAGE REPORT PART USAGE HELPERS
  // ---------------------------------------------------------------------------

  /// Ambil daftar request sparepart dari response job teknisi.
  ///
  /// Backend dari ServiceJobController mengirim:
  ///
  /// job["damage_report"]["part_usages"]
  ///
  /// Method ini dibuat fleksibel supaya tetap aman jika response memakai:
  /// - damage_report
  /// - damageReport
  /// - part_usages
  /// - partUsages
  /// - technician_part_usages
  /// - technicianPartUsages
  static List<Map<String, dynamic>> extractPartUsagesFromJob(dynamic job) {
    final damageReport = _extractDamageReportMap(job);
    final source = damageReport ?? _asMap(job);

    if (source == null) {
      return <Map<String, dynamic>>[];
    }

    final rawList = _extractPartUsageListFromMap(source);

    return rawList
        .map((item) {
          if (item is Map<String, dynamic>) {
            return _normalizePartUsage(item);
          }

          if (item is Map) {
            return _normalizePartUsage(
              Map<String, dynamic>.from(item),
            );
          }

          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Ambil summary request sparepart dari response job teknisi.
  ///
  /// Backend:
  /// damage_report.part_usage_summary
  ///
  /// Kalau backend belum mengirim summary, method ini menghitung dari part_usages.
  static Map<String, dynamic> extractPartUsageSummaryFromJob(dynamic job) {
    final damageReport = _extractDamageReportMap(job);
    final usages = extractPartUsagesFromJob(job);

    final rawSummary = damageReport?["part_usage_summary"] ??
        damageReport?["partUsageSummary"];

    if (rawSummary is Map) {
      final summary = Map<String, dynamic>.from(rawSummary);

      return {
        "total": _intValue(summary["total"]) ?? usages.length,
        "requested": _intValue(summary["requested"] ?? summary["pending"]) ??
            _countByStatus(usages, "requested"),
        "approved": _intValue(summary["approved"]) ??
            _countByStatus(usages, "approved"),
        "rejected": _intValue(summary["rejected"]) ??
            _countByStatus(usages, "rejected"),
      };
    }

    return {
      "total": usages.length,
      "requested": _countByStatus(usages, "requested"),
      "approved": _countByStatus(usages, "approved"),
      "rejected": _countByStatus(usages, "rejected"),
    };
  }

  /// Cek apakah ada request sparepart yang ditolak admin.
  ///
  /// Backend:
  /// damage_report.has_rejected_part_usage
  ///
  /// Kalau backend belum mengirim, dihitung dari part_usages.
  static bool hasRejectedPartUsageFromJob(dynamic job) {
    final damageReport = _extractDamageReportMap(job);

    final rawValue = damageReport?["has_rejected_part_usage"] ??
        damageReport?["hasRejectedPartUsage"];

    if (rawValue is bool) {
      return rawValue;
    }

    if (rawValue != null) {
      final text = rawValue.toString().toLowerCase();
      if (text == "true" || text == "1" || text == "yes") {
        return true;
      }
    }

    final usages = extractPartUsagesFromJob(job);

    return usages.any((usage) {
      return isRejected(usage["status"]);
    });
  }

  /// Ambil alasan penolakan terbaru dari response job.
  ///
  /// Backend:
  /// damage_report.latest_rejected_part_usage_note
  ///
  /// Kalau backend belum mengirim, dicari dari part_usages status rejected.
  static String latestRejectedPartUsageNoteFromJob(dynamic job) {
    final damageReport = _extractDamageReportMap(job);

    final backendNote = cleanAdminNote(
      damageReport?["latest_rejected_part_usage_note"] ??
          damageReport?["latestRejectedPartUsageNote"],
    );

    if (backendNote.isNotEmpty) {
      return backendNote;
    }

    final usages = extractPartUsagesFromJob(job);

    for (final usage in usages) {
      if (isRejected(usage["status"])) {
        final note = getAdminNote(usage);

        if (note.isNotEmpty) {
          return note;
        }
      }
    }

    return "";
  }

  /// Ambil progress label global dari job.
  ///
  /// Contoh:
  /// - Tidak ada request sparepart
  /// - Ada request menunggu approval admin
  /// - Ada request sparepart ditolak admin
  /// - Semua request sparepart disetujui
  static String getPartUsageProgressLabelFromJob(dynamic job) {
    final summary = extractPartUsageSummaryFromJob(job);

    final total = _intValue(summary["total"]) ?? 0;
    final requested = _intValue(summary["requested"]) ?? 0;
    final approved = _intValue(summary["approved"]) ?? 0;
    final rejected = _intValue(summary["rejected"]) ?? 0;

    if (total <= 0) {
      return "Belum ada request sparepart";
    }

    if (rejected > 0) {
      return "Ada request sparepart ditolak admin";
    }

    if (requested > 0) {
      return "Menunggu approval admin";
    }

    if (approved == total) {
      return "Semua request sparepart disetujui";
    }

    return "Progress request sparepart tersedia";
  }

  // ---------------------------------------------------------------------------
  // EXTRACTORS
  // ---------------------------------------------------------------------------

  static int extractPartUsageId(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleId = data["id"] ??
        data["part_usage_id"] ??
        data["partUsageId"] ??
        data["usage"]?["id"] ??
        data["data"]?["id"];

    return int.tryParse(possibleId?.toString() ?? "") ?? 0;
  }

  static int extractDamageReportId(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleId = data["damage_report_id"] ??
        data["damageReportId"] ??
        data["damage_report"]?["id"] ??
        data["damageReport"]?["id"];

    return int.tryParse(possibleId?.toString() ?? "") ?? 0;
  }

  static int extractServiceBookingId(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleId = data["service_booking_id"] ??
        data["booking_id"] ??
        data["serviceBookingId"] ??
        data["bookingId"] ??
        data["service_booking"]?["id"] ??
        data["serviceBooking"]?["id"] ??
        data["booking"]?["id"];

    return int.tryParse(possibleId?.toString() ?? "") ?? 0;
  }

  static int extractPartId(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleId = data["part_id"] ??
        data["partId"] ??
        data["part"]?["id"];

    return int.tryParse(possibleId?.toString() ?? "") ?? 0;
  }

  static int extractQty(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleQty = data["qty"] ??
        data["quantity"] ??
        data["jumlah"];

    return int.tryParse(possibleQty?.toString() ?? "") ?? 0;
  }

  // ---------------------------------------------------------------------------
  // STATUS HELPERS
  // ---------------------------------------------------------------------------

  static String normalizeStatus(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase().trim() ?? "";
    final normalized = status.replaceAll("-", "_").replaceAll(" ", "_");

    switch (normalized) {
      case "requested":
      case "request":
      case "pending":
      case "menunggu":
      case "waiting":
        return "requested";

      case "approved":
      case "approve":
      case "disetujui":
        return "approved";

      case "rejected":
      case "reject":
      case "ditolak":
        return "rejected";

      case "used":
      case "issued":
      case "dipakai":
        return "used";

      case "cancelled":
      case "canceled":
      case "cancel":
      case "dibatalkan":
        return "canceled";

      default:
        return normalized.isEmpty ? "requested" : normalized;
    }
  }

  static String getStatusLabel(dynamic statusValue) {
    final status = normalizeStatus(statusValue);

    switch (status) {
      case "requested":
        return "Pending";

      case "approved":
        return "Approved";

      case "rejected":
        return "Rejected";

      case "used":
        return "Used";

      case "canceled":
        return "Canceled";

      default:
        return statusValue?.toString() ?? "Pending";
    }
  }

  static String getStatusDescription(dynamic statusValue) {
    final status = normalizeStatus(statusValue);

    switch (status) {
      case "requested":
        return "Permintaan sparepart sedang menunggu persetujuan admin.";

      case "approved":
        return "Permintaan sparepart telah disetujui admin dan dapat digunakan untuk perbaikan.";

      case "rejected":
        return "Permintaan sparepart ditolak admin. Periksa catatan admin untuk mengetahui alasannya.";

      case "used":
        return "Sparepart sudah digunakan untuk proses perbaikan.";

      case "canceled":
        return "Permintaan sparepart dibatalkan.";

      default:
        return "Status permintaan sparepart belum dikenali.";
    }
  }

  static bool isPending(dynamic statusValue) {
    return normalizeStatus(statusValue) == "requested";
  }

  static bool isApproved(dynamic statusValue) {
    return normalizeStatus(statusValue) == "approved";
  }

  static bool isRejected(dynamic statusValue) {
    return normalizeStatus(statusValue) == "rejected";
  }

  static bool isUsed(dynamic statusValue) {
    return normalizeStatus(statusValue) == "used";
  }

  static bool isCanceled(dynamic statusValue) {
    return normalizeStatus(statusValue) == "canceled";
  }

  // ---------------------------------------------------------------------------
  // PART DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  static String getPartName(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "-";

    final part = _asMap(data["part"]);

    return part?["name"]?.toString() ??
        data["part_name"]?.toString() ??
        data["partName"]?.toString() ??
        data["name"]?.toString() ??
        "-";
  }

  static String getPartSku(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "-";

    final part = _asMap(data["part"]);

    return part?["sku"]?.toString() ??
        data["part_sku"]?.toString() ??
        data["partSku"]?.toString() ??
        data["sku"]?.toString() ??
        "-";
  }

  static int getPartStock(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return 0;

    final part = _asMap(data["part"]);

    final possibleStock = part?["stock"] ??
        data["part_stock"] ??
        data["partStock"] ??
        data["stock"] ??
        data["available_stock"] ??
        data["qty_available"];

    return int.tryParse(possibleStock?.toString() ?? "") ?? 0;
  }

  static String getAdminNote(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "";

    return cleanAdminNote(
      data["note"] ??
          data["admin_note"] ??
          data["adminNote"] ??
          data["reason"] ??
          data["rejection_reason"] ??
          data["rejectionReason"],
    );
  }

  static String getRejectedReason(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "";

    if (!isRejected(data["status"])) {
      return "";
    }

    return getAdminNote(data);
  }

  static String cleanAdminNote(dynamic value) {
    final note = value?.toString().trim() ?? "";

    if (note.isEmpty) return "";

    return note
        .replaceAll("[ADMIN-REJECT]", "")
        .replaceAll("[ADMIN REJECT]", "")
        .replaceAll("[ADMIN-APPROVE]", "")
        .replaceAll("[ADMIN APPROVE]", "")
        .replaceAll("[ADMIN]", "")
        .trim();
  }

  // ---------------------------------------------------------------------------
  // NORMALIZER
  // ---------------------------------------------------------------------------

  static List<dynamic> _normalizePartList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizePart(item);
      }

      if (item is Map) {
        return _normalizePart(Map<String, dynamic>.from(item));
      }

      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizePart(
    Map<String, dynamic> item,
  ) {
    final part = Map<String, dynamic>.from(item);

    part["id"] ??= part["part_id"];
    part["name"] ??= part["part_name"];
    part["sku"] ??= part["part_sku"];
    part["stock"] ??=
        part["available_stock"] ??
        part["qty_available"] ??
        0;

    return part;
  }

  static List<dynamic> _normalizePartUsageList(List<dynamic> items) {
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return _normalizePartUsage(item);
      }

      if (item is Map) {
        return _normalizePartUsage(Map<String, dynamic>.from(item));
      }

      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizePartUsage(
    Map<String, dynamic> item,
  ) {
    final usage = Map<String, dynamic>.from(item);

    /*
    |--------------------------------------------------------------------------
    | ID utama
    |--------------------------------------------------------------------------
    */
    usage["id"] ??= usage["part_usage_id"] ?? usage["partUsageId"];

    /*
    |--------------------------------------------------------------------------
    | Relasi damage report
    |--------------------------------------------------------------------------
    */
    usage["damage_report_id"] ??=
        usage["damageReportId"] ??
        usage["damage_report"]?["id"] ??
        usage["damageReport"]?["id"];

    usage["damageReportId"] ??= usage["damage_report_id"];

    /*
    |--------------------------------------------------------------------------
    | Relasi service booking / job teknisi
    |--------------------------------------------------------------------------
    */
    usage["service_booking_id"] ??=
        usage["booking_id"] ??
        usage["serviceBookingId"] ??
        usage["bookingId"] ??
        usage["service_booking"]?["id"] ??
        usage["serviceBooking"]?["id"] ??
        usage["booking"]?["id"];

    usage["booking_id"] ??= usage["service_booking_id"];
    usage["serviceBookingId"] ??= usage["service_booking_id"];
    usage["bookingId"] ??= usage["service_booking_id"];

    /*
    |--------------------------------------------------------------------------
    | Relasi part
    |--------------------------------------------------------------------------
    */
    usage["part_id"] ??=
        usage["partId"] ??
        usage["part"]?["id"];

    usage["partId"] ??= usage["part_id"];

    if (usage["part"] is Map) {
      usage["part"] = _normalizePart(
        Map<String, dynamic>.from(usage["part"] as Map),
      );
    }

    /*
    |--------------------------------------------------------------------------
    | Qty & status
    |--------------------------------------------------------------------------
    */
    usage["qty"] ??=
        usage["quantity"] ??
        usage["jumlah"] ??
        0;

    usage["status"] = normalizeStatus(
      usage["status"] ?? usage["status_value"] ?? usage["statusValue"],
    );

    usage["status_label"] = getStatusLabel(usage["status"]);
    usage["status_description"] = getStatusDescription(usage["status"]);

    /*
    |--------------------------------------------------------------------------
    | Convenience flags untuk UI
    |--------------------------------------------------------------------------
    */
    usage["is_pending"] = isPending(usage["status"]);
    usage["is_approved"] = isApproved(usage["status"]);
    usage["is_rejected"] = isRejected(usage["status"]);
    usage["is_used"] = isUsed(usage["status"]);
    usage["is_canceled"] = isCanceled(usage["status"]);

    /*
    |--------------------------------------------------------------------------
    | Convenience display field untuk UI
    |--------------------------------------------------------------------------
    */
    usage["part_name"] ??= getPartName(usage);
    usage["part_sku"] ??= getPartSku(usage);
    usage["part_stock"] ??= getPartStock(usage);

    final cleanNote = getAdminNote(usage);

    usage["admin_note_clean"] = cleanNote;

    if (isRejected(usage["status"])) {
      usage["rejection_reason"] = cleanNote;
    }

    return usage;
  }

  // ---------------------------------------------------------------------------
  // RESPONSE EXTRACTOR
  // ---------------------------------------------------------------------------

  static List<dynamic> _extractList(dynamic data) {
    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final nestedData = data["data"];

      if (nestedData is List) {
        return nestedData;
      }

      if (nestedData is Map<String, dynamic>) {
        final paginatedData = nestedData["data"];

        if (paginatedData is List) {
          return paginatedData;
        }

        final nestedParts = nestedData["parts"];
        if (nestedParts is List) {
          return nestedParts;
        }

        final nestedSpareparts = nestedData["spareparts"];
        if (nestedSpareparts is List) {
          return nestedSpareparts;
        }

        final nestedSpareParts = nestedData["spare_parts"];
        if (nestedSpareParts is List) {
          return nestedSpareParts;
        }

        final nestedUsages = nestedData["usages"];
        if (nestedUsages is List) {
          return nestedUsages;
        }

        final nestedPartUsages = nestedData["part_usages"];
        if (nestedPartUsages is List) {
          return nestedPartUsages;
        }

        final nestedPartUsagesCamel = nestedData["partUsages"];
        if (nestedPartUsagesCamel is List) {
          return nestedPartUsagesCamel;
        }

        final nestedTechnicianPartUsages =
            nestedData["technician_part_usages"];
        if (nestedTechnicianPartUsages is List) {
          return nestedTechnicianPartUsages;
        }

        final nestedTechnicianPartUsagesCamel =
            nestedData["technicianPartUsages"];
        if (nestedTechnicianPartUsagesCamel is List) {
          return nestedTechnicianPartUsagesCamel;
        }
      }

      final rows = data["rows"];
      if (rows is List) {
        return rows;
      }

      final parts = data["parts"];
      if (parts is List) {
        return parts;
      }

      final spareparts = data["spareparts"];
      if (spareparts is List) {
        return spareparts;
      }

      final spareParts = data["spare_parts"];
      if (spareParts is List) {
        return spareParts;
      }

      final usages = data["usages"];
      if (usages is List) {
        return usages;
      }

      final partUsages = data["part_usages"];
      if (partUsages is List) {
        return partUsages;
      }

      final partUsagesCamel = data["partUsages"];
      if (partUsagesCamel is List) {
        return partUsagesCamel;
      }

      final technicianPartUsages = data["technician_part_usages"];
      if (technicianPartUsages is List) {
        return technicianPartUsages;
      }

      final technicianPartUsagesCamel = data["technicianPartUsages"];
      if (technicianPartUsagesCamel is List) {
        return technicianPartUsagesCamel;
      }

      final usage = data["usage"];
      if (usage is List) {
        return usage;
      }
    }

    if (data is Map) {
      return _extractList(
        Map<String, dynamic>.from(data),
      );
    }

    return [];
  }

  static Map<String, dynamic>? _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nestedData = data["data"];

      if (nestedData is Map<String, dynamic>) {
        return nestedData;
      }

      if (nestedData is Map) {
        return Map<String, dynamic>.from(nestedData);
      }

      final usage = data["usage"];

      if (usage is Map<String, dynamic>) {
        return usage;
      }

      if (usage is Map) {
        return Map<String, dynamic>.from(usage);
      }

      final partUsage = data["part_usage"];

      if (partUsage is Map<String, dynamic>) {
        return partUsage;
      }

      if (partUsage is Map) {
        return Map<String, dynamic>.from(partUsage);
      }

      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  static Map<String, dynamic>? _extractDamageReportMap(dynamic value) {
    final data = _asMap(value);

    if (data == null) {
      return null;
    }

    final damageReport = data["damage_report"] ??
        data["damageReport"] ??
        data["report"] ??
        data["damage"];

    final mappedDamageReport = _asMap(damageReport);

    if (mappedDamageReport != null) {
      return mappedDamageReport;
    }

    final nestedData = _asMap(data["data"]);

    if (nestedData != null) {
      final nestedResult = _extractDamageReportMap(nestedData);

      if (nestedResult != null) {
        return nestedResult;
      }
    }

    if (_extractPartUsageListFromMap(data).isNotEmpty) {
      return data;
    }

    return null;
  }

  static List<dynamic> _extractPartUsageListFromMap(
    Map<String, dynamic> data,
  ) {
    final possibleKeys = [
      "part_usages",
      "partUsages",
      "technician_part_usages",
      "technicianPartUsages",
      "usages",
      "usage_items",
      "usageItems",
    ];

    for (final key in possibleKeys) {
      final value = data[key];

      if (value is List) {
        return value;
      }
    }

    final nestedData = _asMap(data["data"]);

    if (nestedData != null) {
      return _extractPartUsageListFromMap(nestedData);
    }

    return <dynamic>[];
  }

  static int _countByStatus(
    List<Map<String, dynamic>> usages,
    String expectedStatus,
  ) {
    return usages.where((usage) {
      return normalizeStatus(usage["status"]) == expectedStatus;
    }).length;
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static String _extractErrorMessage(
    dynamic data,
    String fallback,
  ) {
    if (data is Map<String, dynamic>) {
      final message = data["message"]?.toString();

      if (message != null && message.isNotEmpty) {
        return message;
      }

      final errors = data["errors"];

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

    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
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

    return fallback;
  }
}