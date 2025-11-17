// lib/admin/widgets/admin_settings.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  // ── Cache keys ────────────────────────────────────────────────────────
  static const String _cacheRoleKey = 'user_role';
  static const String _cacheStatusKey = 'user_status';
  static const String _cacheLastCheckKey = 'user_last_check';

  // ── Helper: clear cached profile data ─────────────────────────────────
  static Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRoleKey);
    await prefs.remove(_cacheStatusKey);
    await prefs.remove(_cacheLastCheckKey);
  }

  // ── Helper: logout ───────────────────────────────────────────────────
  static Future<void> _logout(BuildContext context) async {
    final supabase = Supabase.instance.client;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logging out…')),
    );

    try {
      await supabase.auth.signOut();
      await _clearCache();

      if (!context.mounted) return;
      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1172D4), // matches your admin theme
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Admin Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            // ── Manage Users ────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manage users coming soon')),
                );
              },
            ),

            // ── View Reports ────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('View Reports'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reports coming soon')),
                );
              },
            ),

            const Divider(),
            const SizedBox(height: 16),

            // ── Logout button ───────────────────────────────────────
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  await AdminSettings._logout(context);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}