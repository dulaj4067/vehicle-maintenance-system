import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeColorManager {
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  static const String _colorKey = 'app_theme_color';
  static const Color _defaultColor = Colors.white;
  static const String _defaultColorString = 'white';
  static String? _cachedColorString;

  static Future<void> setColor() async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final profileId = supabase.auth.currentUser?.id;
    if (profileId == null) {
      _cachedColorString = _defaultColorString;
      await prefs.setString(_colorKey, _defaultColorString);
      return;
    }

    try {
      final primaryResponse = await supabase
          .from('primary_vehicle')
          .select('vehicle_id')
          .eq('user_id', profileId)
          .maybeSingle();

      String? vehicleColor;
      if (primaryResponse != null && primaryResponse['vehicle_id'] != null) {
        final vehicleResponse = await supabase
            .from('vehicles')
            .select('color')
            .eq('id', primaryResponse['vehicle_id'])
            .eq('profile_id', profileId)
            .maybeSingle();
        vehicleColor = vehicleResponse?['color'] as String?;
      }

      final colorString = vehicleColor ?? _defaultColorString;
      _cachedColorString = colorString;
      await prefs.setString(_colorKey, colorString);
      ThemeColorManager.refresh.value++;
    } catch (e) {
      _cachedColorString = _defaultColorString;
      await prefs.setString(_colorKey, _defaultColorString);
      ThemeColorManager.refresh.value++;
    }
  }

  static Color getColor() {
    _cachedColorString ??= _defaultColorString;
    return _colorFromString(_cachedColorString!);
  }

  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedColorString = prefs.getString(_colorKey) ?? _defaultColorString;
  }

  static Color _colorFromString(String colorString) {
  return switch (colorString.toLowerCase()) {
    'white'  => Colors.white,
    'black'  => Colors.black,
    'gray'   => const Color.fromARGB(255, 250, 250, 250), 
    'red'    => const Color.fromARGB(255, 255, 245, 247), 
    'orange' => const Color.fromARGB(255, 255, 249, 240), 
    'yellow' => const Color.fromARGB(255, 255, 254, 243), 
    'green'  => const Color.fromARGB(255, 244, 250, 244), 
    'blue'   => const Color.fromARGB(255, 241, 249, 254), 
    'violet' => const Color.fromARGB(255, 249, 242, 250), 
    'brown'  => const Color.fromARGB(255, 247, 245, 244), 
    'beige'  => const Color.fromARGB(255, 235, 230, 228), 
    'gold'   => const Color.fromARGB(255, 255, 246, 217), 
    'maroon' => const Color.fromARGB(255, 215, 193, 196), 
    _        => _defaultColor,
  };
}

static Future<void> resetToDefault() async {
    _cachedColorString = _defaultColorString;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorKey, _defaultColorString);
    
    refresh.value++; 
  }

  static Color getSafeColor() {
  final color = getColor();
  return color == Colors.black ? Colors.white : Colors.black;
}
}