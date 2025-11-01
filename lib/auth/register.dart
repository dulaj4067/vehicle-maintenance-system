import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  final documentCtrl = TextEditingController(text: 'No document selected');
  bool loading = false;
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _documentError;
  String? _generalError;
  PlatformFile? _pickedFile;

  static const String _cacheRoleKey = 'user_role';
  static const String _cacheStatusKey = 'user_status';
  static const String _cacheLastCheckKey = 'user_last_check';

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheRoleKey);
    await prefs.remove(_cacheStatusKey);
    await prefs.remove(_cacheLastCheckKey);
  }

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d]'), '');
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Full name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!RegExp(r'^\+?[\d\s-()]+$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordCtrl.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateDocument() {
    if (_pickedFile == null) {
      return 'Please upload a document or image';
    }
    return null;
  }

  void _clearFieldErrors() {
    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _documentError = null;
      _generalError = null;
    });
  }

  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (Platform.isAndroid) {
      status = await Permission.photos.status;
    } else if (Platform.isIOS) {
      status = await Permission.photos.status;
    }

    if (status.isDenied) {
      final result = await (Platform.isAndroid
              ? Permission.photos
              : Permission.photos)
          .request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionDialog();
      return false;
    }

    return status.isGranted;
  }

  Future<void> _showPermissionDialog() async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs access to your storage to upload documents and images. Please enable it in Settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> pickFile() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storage permission is required to pick files.')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          documentCtrl.text = _pickedFile!.name;
          _documentError = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No file selected')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e')),
        );
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registration Successful'),
          content: const Text(
            'Your account has been registered successfully. It is now pending approval by the admin. You will be notified via email once it is verified.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _register() async {
    setState(() => loading = true);
    _clearFieldErrors();

    try {
      final bool isFormValid = await _validatePreRegistration();
      if (!isFormValid || !mounted) {
        return;
      }

      await _performRegistration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<bool> _validatePreRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    final trimmedPhone = phoneCtrl.text.trim();
    final cleanPhone = _cleanPhone(trimmedPhone);

    try {
      // Use RPC to call the database function
      final bool phoneExists = await supabase.rpc(
        'check_phone_exists',
        params: {'phone_to_check': cleanPhone},
      );

      if (phoneExists) {
        setState(() {
          _phoneError = 'Phone number already registered';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phone number already in use')),
          );
        }
        return false; // Stop!
      }
    } catch (e) {
      setState(() {
        _phoneError = 'Error checking phone number';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking phone: $e')),
        );
      }
      return false; // Stop!
    }
    
    // All checks passed
    return true;
  }

  Future<void> _performRegistration() async {
    User? user;
    try {
      final authResponse = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      user = authResponse.user;
      if (user == null) throw AuthException('Failed to create user');

      List<Map<String, dynamic>> documents = [];
      if (_pickedFile != null) {
        try {
          final doc = await _uploadDocument(user.id, _pickedFile!);
          documents.add(doc);
        } catch (uploadError) {
          await supabase.auth.signOut();
          throw Exception('Failed to upload document: $uploadError');
        }
      }

      final cleanPhone = _cleanPhone(phoneCtrl.text.trim());
      await supabase.from('profiles').insert({
        'id': user.id,
        'full_name': nameCtrl.text.trim(),
        'phone': cleanPhone,
        'status': 'pending',
        if (documents.isNotEmpty) 'documents': documents,
      });

      if (!mounted) return;
      await _showSuccessDialog();
    } on AuthException catch (e) {
      await _clearCache();
      String errorMsg = 'Registration failed';
      if (e.statusCode == '422') {
        if (e.message.contains('already a user with that email')) {
          setState(() => _emailError = 'Email already registered');
          errorMsg = 'This email is already in use';
        } else {
          setState(() => _emailError = 'Invalid email format');
        }
      } else if (e.statusCode == '400') {
        errorMsg = 'Invalid registration details';
        setState(() => _generalError = errorMsg);
      } else {
        setState(
            () => _emailError = 'Registration failed. Please try again.');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (user != null) {
        await supabase.auth.signOut();
      }
      await _clearCache();
      String errorMsg = 'Registration failed: ${e.toString()}';

      if (e.toString().contains('profiles_phone_key') ||
          e.toString().contains('23505')) {
        setState(() => _phoneError = 'Phone number already registered');
        errorMsg = 'Phone number already in use';
      } else {
        setState(() => _generalError = errorMsg);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _uploadDocument(
      String userId, PlatformFile pickedFile) async {
    Uint8List fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      throw Exception('Unable to read file');
    }

    final tempDir = await getTemporaryDirectory();
    final extension = pickedFile.extension ?? 'pdf';
    final tempFileName =
        'temp_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final tempFile = File('${tempDir.path}/$tempFileName');
    await tempFile.writeAsBytes(fileBytes);

    final fileName = 'user_${userId}_$tempFileName';

    final uploadedPath = await supabase.storage
        .from('customer_documents')
        .upload(fileName, tempFile);

    await tempFile.delete();

    if (uploadedPath.isEmpty) {
      throw Exception('Upload path is empty, upload failed.');
    }

    final publicUrl = supabase.storage
        .from('customer_documents')
        .getPublicUrl(fileName);

    return {
      'type': 'id_proof',
      's3_link': publicUrl,
    };
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    documentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Center(
                child: Text(
                  'Your App Name',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: _validateName,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  errorText: _phoneError,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: _validatePhone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  errorText: _emailError,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: _validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  errorText: _passwordError,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: _validatePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  errorText: _confirmPasswordError,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: _validateConfirmPassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: documentCtrl,
                readOnly: true,
                onTap: pickFile,
                decoration: InputDecoration(
                  labelText: 'Document or Image',
                  hintText:
                      'Upload a document or image (PDF, DOC, DOCX, JPG, PNG, GIF)',
                  errorText: _documentError,
                  suffixIcon:
                      const Icon(Icons.attach_file, color: Colors.blue),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                validator: (_) => _validateDocument(),
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              if (_generalError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _generalError!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Register', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already 55 have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}