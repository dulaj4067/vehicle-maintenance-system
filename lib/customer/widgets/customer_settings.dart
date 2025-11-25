import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class CustomerSettings extends StatefulWidget {
  const CustomerSettings({super.key});

  @override
  State<CustomerSettings> createState() => _CustomerSettingsState();
}

class _CustomerSettingsState extends State<CustomerSettings> {
  final Color _scaffoldBgColor = const Color(0xFF060606);
  final Color _primaryTextColor = const Color(0xFFF5F0EB);
  final Color _accentColor = const Color(0xFFC0A068);

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
        backgroundColor: _accentColor,
        textColor: _scaffoldBgColor,
        fontSize: 16.0,
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _scaffoldBgColor,
        title: Text('Permission Required', 
          style: TextStyle(color: _primaryTextColor)),
        content: Text(
          'Notifications are disabled in system settings. Please enable them to receive updates.',
          style: TextStyle(color: _primaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); 
            },
            child: Text('Open Settings', style: TextStyle(color: _accentColor)),
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
      if (!mounted) return;
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'Logout failed: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: _primaryTextColor,
        fontSize: 16.0,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _scaffoldBgColor,
        title:  Text('Log out',style: TextStyle(color: _primaryTextColor)),
        content:  Text('Are you sure you want to log out?',style: TextStyle(color: _primaryTextColor)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:  Text('Cancel', style: TextStyle(color: _accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:  Text('Log Out', style: TextStyle(color: _accentColor)),
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
    final Color bgColor = _scaffoldBgColor;
    final Color textColor = _primaryTextColor;
    final Color accentColor = _accentColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
      backgroundColor: bgColor,
      surfaceTintColor: bgColor,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
      ),
      toolbarHeight: 80.0,
      title:  Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: accentColor,
          height: 0.5,
        ),
      ),
    ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: accentColor))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Preferences', textColor),
              
              Container(
                decoration: BoxDecoration(
                  color: textColor.withAlpha(0x0D), 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withAlpha(0x1A)),
                ),
                child: SwitchListTile.adaptive(
                  title:  Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w500,color: textColor),
                  ),
                  subtitle:  Text(
                    'Receive updates and alerts',
                    style: TextStyle(fontSize: 12, color: textColor.withAlpha(0x80)),
                  ),
                  value: _notificationsEnabled,
                  activeThumbColor: accentColor,
                  inactiveThumbColor: textColor.withAlpha(0xCC),
                  activeTrackColor: accentColor.withAlpha(0x66),
                  inactiveTrackColor: textColor.withAlpha(0x1A),
                  onChanged: _toggleNotifications,
                  secondary:  Icon(Icons.notifications_outlined, color: accentColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 32),

              _buildSectionHeader('Account', textColor),

              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _showLogoutConfirmation,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: bgColor),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: bgColor,
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
                  style: TextStyle(color: textColor.withAlpha(0x80), fontSize: 12),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textColor.withAlpha(0x99),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}