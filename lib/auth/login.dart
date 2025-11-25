import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  final Color _scaffoldBgColor = const Color(0xFF060606);
  final Color _primaryTextColor = const Color(0xFFF5F0EB);
  final Color _accentColor = const Color(0xFFC0A068);

  static const String _cacheRoleKey = 'user_role';
  static const String _cacheStatusKey = 'user_status';
  static const String _cacheLastCheckKey = 'user_last_check';

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRoleKey);
    await prefs.remove(_cacheStatusKey);
    await prefs.remove(_cacheLastCheckKey);
  }

  Future<void> _saveOneSignalId(String userId) async {
    try {
      OneSignal.login(userId);

      final id = OneSignal.User.pushSubscription.id;
      if (id != null) {
        await supabase
            .from('profiles')
            .update({'notification_id': id})
            .eq('id', userId);
      }
    } catch (e) {
      print('Error saving notification ID: $e');
    }
  }

  Future<void> _updateCache(String role, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_cacheRoleKey, role);
    await prefs.setString(_cacheStatusKey, status);
    await prefs.setInt(_cacheLastCheckKey, now);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email or username';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value) && !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Please enter a valid email or username';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  void _clearFieldErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });
  }

  Future<void> _login() async {
    _clearFieldErrors();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => loading = true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final user = response.user;
      if (user == null) throw AuthException('Invalid login credentials');

      final profile = await supabase
          .from('profiles')
          .select('role, status')
          .eq('id', user.id)
          .maybeSingle();

      final status = profile?['status'] ?? 'pending';
      final role = profile?['role'] ?? 'customer';

      if (status != 'approved') {
        await supabase.auth.signOut();
        await _clearCache();
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: 'Account not accepted yet',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: _primaryTextColor,
          fontSize: 16.0,
        );
        return;
      }

      await _updateCache(role, status);

      await _saveOneSignalId(user.id);

      if (!mounted) return;
      context.go(role == 'admin' ? '/admin' : '/customer');
    } on AuthException catch (e) {
      await _clearCache();
      String errorMsg = 'Login failed';
      if (e.statusCode == '400') {
        if (e.message.contains('Invalid login credentials')) {
          setState(() => _emailError = 'Invalid email or password');
        } else if (e.message.contains('Email not confirmed')) {
          errorMsg = 'Please check your email to confirm your account';
        }
      } else if (e.statusCode == '422') {
        errorMsg = 'Invalid email or password format';
        setState(() => _emailError = errorMsg);
      } else {
        setState(() => _emailError = 'Invalid email or password');
      }
      if (mounted) {
        Fluttertoast.showToast(
          msg: errorMsg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: _primaryTextColor,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      await _clearCache();
      final errorMsg = 'Login failed: ${e.toString()}';
      setState(() => _generalError = errorMsg);
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'An unexpected error occurred',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: Colors.red,
          textColor: _primaryTextColor,
          fontSize: 16.0,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: _primaryTextColor.withAlpha(179)),
      hintStyle: TextStyle(color: _primaryTextColor.withAlpha(100)),
      errorStyle: const TextStyle(color: Colors.redAccent),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryTextColor.withAlpha(77)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryTextColor.withAlpha(77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _accentColor),
      ),
    );

    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Text(
                  'Your App Name', 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold,
                    color: _primaryTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Center(
                child: Icon(
                  Icons.account_circle,
                  size: 80,
                  color: _accentColor,
                ),
              ),
              const SizedBox(height: 40),

              TextFormField(
                controller: emailCtrl,
                style: TextStyle(color: _primaryTextColor),
                cursorColor: _accentColor,
                keyboardType: TextInputType.emailAddress,
                decoration: inputDecoration.copyWith(
                  labelText: 'Email or Username',
                  hintText: 'Enter your email or username',
                  errorText: _emailError,
                ),
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: passwordCtrl,
                style: TextStyle(color: _primaryTextColor),
                cursorColor: _accentColor,
                obscureText: true,
                decoration: inputDecoration.copyWith(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  errorText: _passwordError,
                ),
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Fluttertoast.showToast(
                      msg: 'Forgot Password functionality coming soon',
                      toastLength: Toast.LENGTH_LONG,
                      gravity: ToastGravity.TOP,
                      backgroundColor: _accentColor,
                      textColor: _scaffoldBgColor,
                      fontSize: 16.0,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _accentColor,
                  ),
                  child: const Text('Forgot Password?'),
                ),
              ),
              if (_generalError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _generalError!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: _scaffoldBgColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: _accentColor.withAlpha(128),
                ),
                child: loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: _scaffoldBgColor,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.go('/register'),
                style: TextButton.styleFrom(
                  foregroundColor: _accentColor,
                ),
                child: const Text('Don\'t have an account? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}