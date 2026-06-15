import 'package:flutter/material.dart';

// Repair (Driver)
import 'package:djatimobile_project/pages/repair/repair_status_page.dart';
import 'package:djatimobile_project/pages/repair/damage_report_page.dart';

// Mechanic (Teknisi)
import 'package:djatimobile_project/pages/mechanic/mechanic_history_page.dart';
import 'package:djatimobile_project/pages/mechanic/mechanic_flow.dart';
import 'package:djatimobile_project/pages/mechanic/mechanic_profile_page.dart';

// Profile (General)
import 'package:djatimobile_project/pages/mechanic/profile_page.dart';

class MainNavigation extends StatefulWidget {
  final String userRole;

  const MainNavigation({
    super.key,
    required this.userRole,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  late List<Widget> pages;
  late List<BottomNavigationBarItem> items;

  @override
  void initState() {
    super.initState();
    _setupNavigation();
  }

  void _setupNavigation() {
    final role = widget.userRole.trim().toLowerCase();

    // =========================
    // TEKNISI
    // =========================
    if (role == "teknisi") {
      pages = const [
        MechanicHistoryPage(),
        MechanicTasksFlow(),
        MechanicProfilePage(),
      ];

      items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }

    // =========================
    // DRIVER
    // Analytics sudah dihapus
    // =========================
    else if (role == "driver") {
      pages = const [
        RepairStatusPage(),
        DamageReportPage(),
        ProfilePage(),
      ];

      items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.track_changes),
          label: 'Status',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.report),
          label: 'Report',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }

    // =========================
    // FALLBACK
    // =========================
    else {
      pages = const [
        Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(
            child: Text(
              "Role tidak dikenali",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ];

      items = const [
        BottomNavigationBarItem(
          icon: Icon(Icons.error),
          label: 'Error',
        ),
      ];
    }
  }

  void _onItemTapped(int index) {
    if (index < 0 || index >= pages.length) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFF9A825),
        unselectedItemColor: Colors.white24,
        backgroundColor: const Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: items,
      ),
    );
  }
}