import 'package:flutter/material.dart';
import 'customer_home.dart';
import 'customer_settings.dart';

class CustomerNav extends StatefulWidget {
  const CustomerNav({super.key});

  @override
  State<CustomerNav> createState() => _CustomerNavState();
}

class _CustomerNavState extends State<CustomerNav> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    CustomerHome(),
    CustomerSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}