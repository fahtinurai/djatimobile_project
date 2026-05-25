import 'package:flutter/material.dart';
import 'package:djatimobile_project/core/services/vehicle_daily_log_service.dart';

class VehicleDailyLogPage extends StatefulWidget {
  const VehicleDailyLogPage({super.key});

  @override
  State<VehicleDailyLogPage> createState() => _VehicleDailyLogPageState();
}

class _VehicleDailyLogPageState extends State<VehicleDailyLogPage> {
  final TextEditingController _logDateController = TextEditingController();
  final TextEditingController _shiftController = TextEditingController();
  final TextEditingController _hmStartController = TextEditingController();
  final TextEditingController _hmEndController = TextEditingController();
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _logDateController.text = _formatDateForApi(_selectedDate);
  }

  String _formatDateForApi(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return "$year-$month-$day";
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _logDateController.text = _formatDateForApi(pickedDate);
      });
    }
  }

  double? _parseDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  Future<void> _submitLog() async {
    final logDate = _logDateController.text.trim();
    final shift = _shiftController.text.trim();
    final hmStart = _parseDouble(_hmStartController.text);
    final hmEnd = _parseDouble(_hmEndController.text);
    final fuelLiters = _parseDouble(_fuelController.text);
    final note = _noteController.text.trim();

    if (logDate.isEmpty ||
        shift.isEmpty ||
        hmStart == null ||
        hmEnd == null ||
        fuelLiters == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi tanggal, shift, HM awal, HM akhir, dan fuel."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (hmEnd < hmStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hour Meter akhir tidak boleh lebih kecil dari HM awal."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (fuelLiters < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fuel liters tidak boleh negatif."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await VehicleDailyLogService.submitLog(
        logDate: logDate,
        shift: shift,
        hourMeterStart: hmStart,
        hourMeterEnd: hmEnd,
        fuelLiters: fuelLiters,
        note: note.isEmpty ? null : note,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Daily unit log berhasil disimpan."),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _shiftController.clear();
          _hmStartController.clear();
          _hmEndController.clear();
          _fuelController.clear();
          _noteController.clear();
        });
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _logDateController.dispose();
    _shiftController.dispose();
    _hmStartController.dispose();
    _hmEndController.dispose();
    _fuelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white24,
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        suffixIcon: readOnly
            ? const Icon(
                Icons.calendar_month,
                color: Color(0xFFF9A825),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Daily Unit Log",
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
            const Text(
              "Input aktivitas harian kendaraan",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            _buildLabel("Tanggal Log"),
            const SizedBox(height: 10),
            _buildInput(
              _logDateController,
              "YYYY-MM-DD",
              readOnly: true,
              onTap: _pickDate,
            ),

            const SizedBox(height: 20),

            _buildLabel("Shift"),
            const SizedBox(height: 10),
            _buildInput(
              _shiftController,
              "Contoh: Shift 1 / Pagi / Malam",
            ),

            const SizedBox(height: 20),

            _buildLabel("Hour Meter Awal"),
            const SizedBox(height: 10),
            _buildInput(
              _hmStartController,
              "Contoh: 1200.50",
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel("Hour Meter Akhir"),
            const SizedBox(height: 10),
            _buildInput(
              _hmEndController,
              "Contoh: 1240.75",
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel("Fuel Liters"),
            const SizedBox(height: 10),
            _buildInput(
              _fuelController,
              "Contoh: 180",
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 20),

            _buildLabel("Catatan"),
            const SizedBox(height: 10),
            _buildInput(
              _noteController,
              "Catatan operasional kendaraan...",
              maxLines: 3,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _submitLog,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.black,
                      )
                    : const Text(
                        "SUBMIT DAILY LOG",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}