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

  final List<Widget> _screens = [
    const AdminHome(),
    const RegistrationManagementScreen(),
    const ServiceSlotManagementScreen(),
    const BookingRequestManagementScreen(),
    const MarketingCampaignManagementScreen(),
    const AdminSettings(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF0D141B),
      ),
      drawer: AdminSideDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      body: _screens[_selectedIndex],
    );
  }
}