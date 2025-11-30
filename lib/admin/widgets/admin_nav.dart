import 'package:flutter/material.dart';

import 'admin_side_drawer.dart';
import 'admin_home.dart';
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

  final List<Widget> _screens = [
    const AdminHome(),
    const RegistrationManagementScreen(),
    const ServiceSlotManagementScreen(),
    const BookingRequestManagementScreen(),
    const MarketingCampaignManagementScreen(),
    const AdminSettings(),
  ];

  static const List<String> _titles = [
    'Dashboard',
    'Registrations',
    'Service Schedule',
    'Bookings',
    'Campaigns',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    // Register navigation callback
    AdminNavigationController.onNavigate = _onItemTapped;
  }

  @override
  void dispose() {
    // Clean up callback
    AdminNavigationController.onNavigate = null;
    super.dispose();
  }

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
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.grey.withValues(alpha: 0.08),
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