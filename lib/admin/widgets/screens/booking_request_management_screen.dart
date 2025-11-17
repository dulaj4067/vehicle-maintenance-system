import 'package:flutter/material.dart';

class BookingRequestManagementScreen extends StatelessWidget {
  const BookingRequestManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome to Booking Request Management',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}