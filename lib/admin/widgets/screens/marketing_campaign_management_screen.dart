import 'package:flutter/material.dart';

class MarketingCampaignManagementScreen extends StatelessWidget {
  const MarketingCampaignManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome to Marketing Campaign Management',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}