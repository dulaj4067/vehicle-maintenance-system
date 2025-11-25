import 'package:flutter/material.dart';
import 'customer_home.dart';
import 'customer_vehicles.dart';
import 'customer_bookings.dart';
import 'customer_profile.dart';
import 'customer_settings.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomerNav extends StatefulWidget {
  const CustomerNav({super.key});

  @override
  State<CustomerNav> createState() => _CustomerNavState();
}

class _CustomerNavState extends State<CustomerNav> {
  int _currentIndex = 0;

  final Color _scaffoldBgColor = const Color(0xFF060606);
  final Color _primaryTextColor = const Color(0xFFF5F0EB);
  final Color _accentColor = const Color(0xFFC0A068);

  final List<Widget> _pages = [
    const CustomerHome(),
    const CustomerVehicles(),
    const CustomerBookings(),
    const CustomerProfile(),
    const CustomerSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _scaffoldBgColor,
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _accentColor,
                  width: 0.7,
                ),
              ),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: _scaffoldBgColor,
              elevation: 0,
              selectedItemColor: _accentColor,
              unselectedItemColor: _primaryTextColor.withAlpha(170),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: [
                BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.house, size: 18),
                  activeIcon: FaIcon(FontAwesomeIcons.solidHouse,
                      size: 18, color: _accentColor),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.car, size: 18),
                  activeIcon:
                      FaIcon(FontAwesomeIcons.car, size: 18, color: _accentColor),
                  label: 'Vehicles',
                ),
                BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.calendar, size: 18),
                  activeIcon: FaIcon(FontAwesomeIcons.solidCalendar,
                      size: 18, color: _accentColor),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.user, size: 18),
                  activeIcon: FaIcon(FontAwesomeIcons.solidUser,
                      size: 18, color: _accentColor),
                  label: 'Profile',
                ),
                BottomNavigationBarItem(
                  icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
                  activeIcon:
                      FaIcon(FontAwesomeIcons.gear, size: 18, color: _accentColor),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}