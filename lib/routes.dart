import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login.dart';
import 'auth/register.dart';
import 'admin/widgets/admin_nav.dart';
import 'customer/widgets/customer_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// Cache keys
const String _cacheRoleKey = 'user_role';
const String _cacheStatusKey = 'user_status';
const String _cacheLastCheckKey = 'user_last_check';
const Duration _cacheExpiration = Duration(hours: 48);

Future<GoRouter> getRouter() async {
  final user = supabase.auth.currentUser;

  if (user == null) {
    return _buildRouter('/login');
  }

  // Try to load cache
  final prefs = await SharedPreferences.getInstance();
  final cachedRole = prefs.getString(_cacheRoleKey);
  final cachedStatus = prefs.getString(_cacheStatusKey);
  final lastCheck = prefs.getInt(_cacheLastCheckKey) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;

  // Use cache if valid and recent
  if (cachedStatus == 'approved' &&
      cachedRole != null &&
      now - lastCheck < _cacheExpiration.inMilliseconds) {
    final initialRoute = cachedRole == 'admin' ? '/admin' : '/customer';
    return _buildRouter(initialRoute);
  }

  // Cache invalid/expired: Fetch from DB
  final response = await supabase
      .from('profiles')
      .select('role, status')
      .eq('id', user.id)
      .maybeSingle();

  final role = response?['role'] ?? '';
  final status = response?['status'] ?? '';

  // Update cache with fresh data
  await prefs.setString(_cacheRoleKey, role);
  await prefs.setString(_cacheStatusKey, status);
  await prefs.setInt(_cacheLastCheckKey, now);

  if (status != 'approved') {
    await supabase.auth.signOut();
    // Clear cache on sign-out
    await prefs.remove(_cacheRoleKey);
    await prefs.remove(_cacheStatusKey);
    await prefs.remove(_cacheLastCheckKey);
    return _buildRouter('/login');
  }

  final initialRoute = role == 'admin' ? '/admin' : '/customer';

  return _buildRouter(initialRoute);
}

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (context, state) => LoginPage()),
      GoRoute(path: '/admin', builder: (context, state) => AdminNav()),
      GoRoute(path: '/customer', builder: (context, state) => CustomerNav()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
    ],
  );
}