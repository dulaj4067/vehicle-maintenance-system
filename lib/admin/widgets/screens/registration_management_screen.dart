import 'package:flutter/material.dart';

class RegistrationManagementScreen extends StatelessWidget {
  const RegistrationManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome to Registration Management',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}