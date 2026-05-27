import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String? status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  String get _label {
    final value = (status ?? '').toLowerCase();

    switch (value) {
      case 'menunggu':
      case 'waiting':
      case 'reported':
        return 'Reported';

      case 'diproses':
      case 'in_progress':
      case 'in progress':
        return 'In Progress';

      case 'menunggu_sparepart':
      case 'waiting_parts':
      case 'waiting parts':
        return 'Waiting Parts';

      case 'selesai':
      case 'completed':
        return 'Completed';

      case 'canceled':
      case 'cancelled':
        return 'Canceled';

      default:
        return status == null || status!.isEmpty ? 'Reported' : status!;
    }
  }

  Color get _color {
    final value = (status ?? '').toLowerCase();

    switch (value) {
      case 'menunggu':
      case 'waiting':
      case 'reported':
        return Colors.orange;

      case 'diproses':
      case 'in_progress':
      case 'in progress':
        return Colors.blue;

      case 'menunggu_sparepart':
      case 'waiting_parts':
      case 'waiting parts':
        return Colors.redAccent;

      case 'selesai':
      case 'completed':
        return Colors.green;

      case 'canceled':
      case 'cancelled':
        return Colors.grey;

      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}