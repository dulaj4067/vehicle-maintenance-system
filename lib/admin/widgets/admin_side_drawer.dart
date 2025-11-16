// lib/admin/widgets/admin_side_drawer.dart
import 'package:flutter/material.dart';

class AdminSideDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AdminSideDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<AdminSideDrawer> createState() => _AdminSideDrawerState();
}

class _AdminSideDrawerState extends State<AdminSideDrawer> {
  final List<_NavItem> _items = [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.person, label: 'Registration Management'),
    _NavItem(icon: Icons.calendar_today, label: 'Service Slot Management'),
    _NavItem(icon: Icons.directions_car, label: 'Booking Request Management'),
    _NavItem(icon: Icons.campaign, label: 'Marketing Campaign Management'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
            child: const Text(
              'Admin',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D141B),
                letterSpacing: -0.33,
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = widget.selectedIndex == index;

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    widget.onItemTapped(index);
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE7EDF3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 24, color: const Color(0xFF0D141B)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D141B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Divider
          const Divider(height: 1),

          // Settings at Bottom
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xFF0D141B)),
            title: const Text(
              'Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D141B),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onItemTapped(5);
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}