import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineWrapper extends StatelessWidget {
  final Widget? child;

  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        // If we are waiting for the first check, or if we have a connection, show the app
        final results = snapshot.data;
        
        // Check if there is NO connection type available
        final isOffline = results != null && 
                          results.contains(ConnectivityResult.none) && 
                          results.length == 1;

        if (isOffline) {
          return const Scaffold(
            backgroundColor:Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No Internet Connection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Please check your settings.'),
                ],
              ),
            ),
          );
        }

        // If online (or loading), return the actual app content
        return child ?? const SizedBox.shrink();
      },
    );
  }
}