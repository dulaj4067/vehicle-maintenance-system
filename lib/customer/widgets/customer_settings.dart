import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme_color.dart'; 
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class CustomerSettings extends StatefulWidget {
  const CustomerSettings({super.key});

  @override
  State<CustomerSettings> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<CustomerSettings> {
  static const String _cacheRoleKey = 'user_role';
  static const String _cacheStatusKey = 'user_status';
  static const String _cacheLastCheckKey = 'user_last_check';
  
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      var status = await Permission.notification.status;
      
      if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDialog();
        }
        return; 
      } else if (status.isDenied) {
        status = await Permission.notification.request();
        if (!status.isGranted) return; 
      }
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = value;
    });
    await prefs.setBool('notifications_enabled', value);

    if (mounted) {
      Fluttertoast.showToast(
        msg: value ? 'Notifications enabled' : 'Notifications disabled',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: ThemeColorManager.getSafeColor(),
        textColor: ThemeColorManager.getColor(),
        fontSize: 16.0,
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorManager.getColor(),
        title: Text('Permission Required', 
          style: TextStyle(color: ThemeColorManager.getSafeColor())),
        content: Text(
          'Notifications are disabled in system settings. Please enable them to receive updates.',
          style: TextStyle(color: ThemeColorManager.getSafeColor()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: ThemeColorManager.getSafeColor())),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); 
            },
            child: Text('Open Settings', style: TextStyle(color: ThemeColorManager.getSafeColor())),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRoleKey);
    await prefs.remove(_cacheStatusKey);
    await prefs.remove(_cacheLastCheckKey);
    await prefs.remove('notifications_enabled'); 
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      await supabase.auth.signOut();
      await _clearCache();
      await ThemeColorManager.resetToDefault();
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'Logout failed: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: ThemeColorManager.getSafeColor(),
        textColor: ThemeColorManager.getColor(),
        fontSize: 16.0,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColorManager.getColor(),
        title:  Text('Log out',style: TextStyle(color: ThemeColorManager.getSafeColor())),
        content:  Text('Are you sure you want to log out?',style: TextStyle(color: ThemeColorManager.getSafeColor())),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:  Text('Cancel', style: TextStyle(color: ThemeColorManager.getSafeColor())),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:  Text('Log Out', style: TextStyle(color: ThemeColorManager.getSafeColor())),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColorManager.getColor(),
      appBar: AppBar(
      backgroundColor: ThemeColorManager.getColor(),
      surfaceTintColor: ThemeColorManager.getColor(),
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      toolbarHeight: 80.0,
      title:  Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: ThemeColorManager.getSafeColor(),
          ),
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: Colors.grey,
          height: 0.5,
        ),
      ),
    ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Preferences'),
              
              Container(
                decoration: BoxDecoration(
                  color: ThemeColorManager.getColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeColorManager.getColor()),
                ),
                child: SwitchListTile.adaptive(
                  title:  Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w500,color: ThemeColorManager.getSafeColor()),
                  ),
                  subtitle:  Text(
                    'Receive updates and alerts',
                    style: TextStyle(fontSize: 12, color: ThemeColorManager.getSafeColor()),
                  ),
                  value: _notificationsEnabled,
                  activeThumbColor: ThemeColorManager.getColor(),
                  inactiveTrackColor: ThemeColorManager.getColor(),
                  activeTrackColor:ThemeColorManager.getSafeColor(),
                  inactiveThumbColor: ThemeColorManager.getSafeColor(),
                  onChanged: _toggleNotifications,
                  secondary:  Icon(Icons.notifications_outlined, color: ThemeColorManager.getSafeColor()),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 32),

              _buildSectionHeader('Account'),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _showLogoutConfirmation,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: ThemeColorManager.getSafeColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: ThemeColorManager.getSafeColor()),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: ThemeColorManager.getColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(color: ThemeColorManager.getSafeColor(), fontSize: 12),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: ThemeColorManager.getSafeColor(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}