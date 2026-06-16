import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';
import '../auth/login_page.dart';

class MechanicProfilePage extends StatefulWidget {
  const MechanicProfilePage({super.key});

  @override
  State<MechanicProfilePage> createState() => _MechanicProfilePageState();
}

class _MechanicProfilePageState extends State<MechanicProfilePage> {
  static const String baseUrl = "https://proting3-backend-production.up.railway.app/api";

  static const Color bgColor = Color(0xFF0F1115);
  static const Color cardColor = Color(0xFF1A1D24);
  static const Color softCardColor = Color(0xFF20242D);
  static const Color primaryColor = Color(0xFFF9A825);

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

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
        Uri.parse("$baseUrl/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("MECHANIC PROFILE STATUS: ${response.statusCode}");
      debugPrint("MECHANIC PROFILE BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        Map<String, dynamic>? userData;

        if (decoded is Map<String, dynamic>) {
          if (decoded["user"] is Map<String, dynamic>) {
            userData = decoded["user"];
          } else if (decoded["data"] is Map<String, dynamic>) {
            userData = decoded["data"];
          } else {
            userData = decoded;
          }
        }

        if (!mounted) return;

        setState(() {
          _user = userData;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        throw Exception("Sesi login sudah berakhir. Silakan login ulang.");
      } else {
        throw Exception("Gagal mengambil profile: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Logout?",
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            "Kamu akan keluar dari akun teknisi dan kembali ke halaman login.",
            style: TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Batal",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                "Logout",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    try {
      final token = await AuthService.getToken();

      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse("$baseUrl/logout"),
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        );
      }
    } catch (e) {
      debugPrint("MECHANIC LOGOUT ERROR: $e");
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  String get _displayName {
    final name = _user?["name"]?.toString();
    final username = _user?["username"]?.toString();

    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    if (username != null && username.trim().isNotEmpty) {
      return username;
    }

    return "Mechanic";
  }

  String get _displayRole {
    final role = _user?["role"]?.toString() ?? "-";

    if (role.toLowerCase() == "teknisi") {
      return "MECHANIC";
    }

    if (role.toLowerCase() == "mechanic") {
      return "MECHANIC";
    }

    if (role.toLowerCase() == "technician") {
      return "MECHANIC";
    }

    return role.toUpperCase();
  }

  String get _userId {
    return _user?["id"]?.toString() ?? "-";
  }

  String get _username {
    return _user?["username"]?.toString() ?? "-";
  }

  String get _createdAt {
    return _formatDate(_user?["created_at"]);
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty || raw == "null") {
      return "-";
    }

    try {
      final normalized =
          raw.contains(" ") && !raw.contains("T") ? raw.replaceFirst(" ", "T") : raw;

      final date = DateTime.parse(normalized).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();

      return "$day-$month-$year";
    } catch (_) {
      return raw;
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: primaryColor,
      backgroundColor: cardColor,
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          _buildProfileHero(),
          const SizedBox(height: 16),
          _buildUserInfoCard(),
          const SizedBox(height: 16),
          _buildLogoutCard(),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              "DJATI Mobile Technician Panel",
              style: TextStyle(
                color: Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(28),
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
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.85),
                      Colors.lightBlueAccent.withOpacity(0.72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.engineering_rounded,
                    color: Colors.black,
                    size: 54,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.lightBlueAccent.withOpacity(0.60),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.lightBlueAccent,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _statusChip(_displayRole, Colors.lightBlueAccent),
          const SizedBox(height: 14),
          Text(
            _username == "-" ? "Username belum tersedia" : "@$_username",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return _sectionCard(
      title: "Technician Information",
      icon: Icons.badge_outlined,
      child: _buildInfoGrid([
        _InfoItem(
          title: "User ID",
          value: _userId,
          icon: Icons.tag_rounded,
          color: primaryColor,
        ),
        _InfoItem(
          title: "Username",
          value: _username,
          icon: Icons.alternate_email_rounded,
          color: Colors.lightBlueAccent,
        ),
        _InfoItem(
          title: "Role",
          value: _displayRole,
          icon: Icons.engineering_outlined,
          color: Colors.greenAccent,
        ),
        _InfoItem(
          title: "Joined",
          value: _createdAt,
          icon: Icons.calendar_month_outlined,
          color: Colors.purpleAccent,
        ),
      ]),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.18),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _confirmLogout,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _iconBadge(
                icon: Icons.logout_rounded,
                color: Colors.redAccent,
                size: 44,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Keluar dari akun teknisi saat ini",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.redAccent,
                size: 15,
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
          _sectionTitle(title, icon),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
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
          letterSpacing: 0.4,
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBadge(
                icon: Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 58,
              ),
              const SizedBox(height: 16),
              const Text(
                "Gagal memuat profil teknisi",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _loadProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    "Coba Lagi",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Technician Profile",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: false,
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Refresh Profile",
            onPressed: _loadProfile,
            icon: const Icon(
              Icons.refresh_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 6),
        ],
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
        child: _buildBody(),
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