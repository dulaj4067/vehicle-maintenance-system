import 'package:flutter/material.dart';

import 'admin_side_drawer.dart';
import 'admin_Home.dart';
import 'screens/registration_management_screen.dart';
import 'screens/service_slot_management_screen.dart';
import 'screens/booking_request_management_screen.dart';
import 'screens/marketing_campaign_management_screen.dart';
import 'admin_settings.dart';

class AdminNav extends StatefulWidget {
  const AdminNav({super.key});

  @override
  State<AdminNav> createState() => _AdminNavState();
}

class _AdminNavState extends State<AdminNav> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    AdminHome(),
    RegistrationManagementScreen(),
    ServiceSlotManagementScreen(),
    BookingRequestManagementScreen(),
    MarketingCampaignManagementScreen(),
    AdminSettings(),
  ];

  static const List<String> _titles = [
    'Dashboard',
    'Registrations',
    'Service Schedule',
    'Bookings',
    'Campaigns',
    'Settings',
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D141B),
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,

        // This is the ONLY part that changed — clean ash tint + visible shadow
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.grey.withValues(alpha: 0.08), // beautiful ash tint (not purple!)
        shadowColor: Colors.grey.withValues(alpha: 0.2),
        elevation: 0,
      ),
      drawer: AdminSideDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      body: _screens[_selectedIndex],
    );
  }
}