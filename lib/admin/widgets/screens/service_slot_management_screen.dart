import 'package:flutter/material.dart';

class ServiceSlotManagementScreen extends StatelessWidget {
  const ServiceSlotManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome to Service Slot Management',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}