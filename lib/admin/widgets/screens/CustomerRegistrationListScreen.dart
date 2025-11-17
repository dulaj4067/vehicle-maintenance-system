// lib/admin/screens/customer_registration_list_screen.dart
import 'package:flutter/material.dart';

class CustomerRegistrationListScreen extends StatelessWidget {
  const CustomerRegistrationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1172D4),
        foregroundColor: Colors.white,
        title: const Text('Customer Registrations'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: Colors.blue[700],
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Customer Registration Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D141B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Pending customer sign-ups will appear here\nfor approval or rejection',
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