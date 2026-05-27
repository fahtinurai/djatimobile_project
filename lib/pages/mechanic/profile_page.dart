import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:djatimobile_project/core/services/auth_service.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String baseUrl = "http://10.0.2.2:8000/api";

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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

      print("PROFILE STATUS: ${response.statusCode}");
      print("PROFILE BODY: ${response.body}");

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
      } else {
        throw Exception("Gagal mengambil profile: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
      print("LOGOUT ERROR: $e");
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  String get _displayName {
    final name = _user?["name"]?.toString();
    final username = _user?["username"]?.toString();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return "User";
  }

  String get _displayRole {
    final role = _user?["role"]?.toString() ?? "-";

    if (role.toLowerCase() == "driver") {
      return "OPERATOR";
    }

    return role.toUpperCase();
  }

  String get _userId {
    return _user?["id"]?.toString() ?? "-";
  }

  String get _username {
    return _user?["username"]?.toString() ?? "-";
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
                onPressed: _loadProfile,
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

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFF1E1E1E),
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Color(0xFFF9A825),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayRole,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildUserInfoCard(),

            const SizedBox(height: 28),

            _buildMenuItem(
              Icons.notifications_none,
              "Notification Settings",
            ),
            _buildMenuItem(
              Icons.help_outline,
              "Help & Support",
            ),
            _buildMenuItem(
              Icons.privacy_tip_outlined,
              "Privacy Policy",
            ),

            const Divider(
              color: Colors.white10,
              height: 40,
              indent: 20,
              endIndent: 20,
            ),

            ListTile(
              onTap: _logout,
              leading: const Icon(
                Icons.logout,
                color: Colors.redAccent,
              ),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow("User ID", _userId),
          const SizedBox(height: 14),
          _buildInfoRow("Username", _username),
          const SizedBox(height: 14),
          _buildInfoRow("Role", _displayRole),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return ListTile(
      onTap: () {},
      leading: Icon(
        icon,
        color: Colors.white70,
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white24,
        size: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFFF9A825),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }
}