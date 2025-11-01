import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static Future<void> saveLoginInfo(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role); // 'admin' or 'customer'
    await prefs.setBool('isLoggedIn', true);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}