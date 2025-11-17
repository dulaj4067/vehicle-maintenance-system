// lib/admin/screens/registration_management_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegistrationManagementScreen extends StatelessWidget {
  const RegistrationManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Fully hidden top bar
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // CUSTOMER REGISTRATION FIRST (Now at the top)
              _buildNavigationCard(
                context: context,
                title: 'Customer Registration Requests',
                subtitle: 'Review and approve/reject new customer sign-ups',
                icon: Icons.person_add,
                color: Colors.blue,
                onTap: () => context.push('/admin/screens/customers'),
              ),

              const SizedBox(height: 20),

              // VEHICLE REGISTRATION SECOND
              _buildNavigationCard(
                context: context,
                title: 'Vehicle Registration Requests',
                subtitle: 'Verify and approve/reject customer vehicles',
                icon: Icons.directions_car,
                color: Colors.green,
                onTap: () => context.push('/admin/screens/vehicles'),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, size: 38, color: color),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D141B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}