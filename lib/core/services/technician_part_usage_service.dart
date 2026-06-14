import 'package:djatimobile_project/core/services/api_service.dart';

class TechnicianPartUsageService {
  // ---------------------------------------------------------------------------
  // PARTS
  // ---------------------------------------------------------------------------

  /// Ambil daftar sparepart untuk dipilih teknisi.
  ///
  /// Backend:
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
  /// Body lama:
  /// {
  ///   "part_id": 1,
  ///   "damage_report_id": 5,
  ///   "qty": 2,
  ///   "note": "Catatan"
  /// }
  ///
  /// Body baru yang lebih kuat:
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
  /// - damage_report_id tetap dikirim agar kompatibel dengan backend lama.
  /// - service_booking_id / booking_id dikirim agar sparepart menempel jelas
  ///   ke job teknisi dari maintenance scheduling.
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
  // EXTRACTORS
  // ---------------------------------------------------------------------------

  static int extractPartUsageId(Map<String, dynamic> value) {
    final data = _extractMap(value) ?? value;

    final possibleId = data["id"] ??
        data["part_usage_id"] ??
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

  static String getStatusLabel(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "requested";

    switch (status) {
      case "requested":
      case "pending":
        return "Pending";

      case "approved":
        return "Approved";

      case "rejected":
        return "Rejected";

      case "used":
      case "issued":
        return "Used";

      case "cancelled":
      case "canceled":
        return "Canceled";

      default:
        return statusValue?.toString() ?? "Pending";
    }
  }

  static bool isPending(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "";

    return status == "requested" || status == "pending";
  }

  static bool isApproved(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "";

    return status == "approved";
  }

  static bool isRejected(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "";

    return status == "rejected";
  }

  static bool isUsed(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "";

    return status == "used" || status == "issued";
  }

  static bool isCanceled(dynamic statusValue) {
    final status = statusValue?.toString().toLowerCase() ?? "";

    return status == "cancelled" || status == "canceled";
  }

  // ---------------------------------------------------------------------------
  // PART DISPLAY HELPERS
  // ---------------------------------------------------------------------------

  static String getPartName(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "-";

    final part = _extractMap(data["part"]);

    return part?["name"]?.toString() ??
        data["part_name"]?.toString() ??
        data["name"]?.toString() ??
        "-";
  }

  static String getPartSku(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return "-";

    final part = _extractMap(data["part"]);

    return part?["sku"]?.toString() ??
        data["part_sku"]?.toString() ??
        data["sku"]?.toString() ??
        "-";
  }

  static int getPartStock(dynamic value) {
    final data = _extractMap(value);

    if (data == null) return 0;

    final part = _extractMap(data["part"]);

    final possibleStock = part?["stock"] ??
        data["stock"] ??
        data["available_stock"] ??
        data["qty_available"];

    return int.tryParse(possibleStock?.toString() ?? "") ?? 0;
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
    usage["id"] ??= usage["part_usage_id"];

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
    |
    | Ini penting agar sparepart bisa ditampilkan lebih akurat pada job teknisi,
    | bukan hanya dicocokkan lewat damage_report_id.
    |
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

    usage["status"] ??= "requested";
    usage["status_label"] = getStatusLabel(usage["status"]);

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