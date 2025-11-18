// lib/admin/screens/vehicle_registration_list_screen.dart
import 'package:flutter/material.dart';

class VehicleRegistrationListScreen extends StatelessWidget {
  const VehicleRegistrationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1172D4),
        foregroundColor: Colors.white,
        title: const Text('Vehicle Registrations'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 80,
              color: Colors.green[700],
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Vehicle Registration Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D141B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Pending vehicle submissions will appear here\nfor verification and approval',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}