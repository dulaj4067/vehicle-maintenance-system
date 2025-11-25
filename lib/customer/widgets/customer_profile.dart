import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../theme_color.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CustomerProfile extends StatefulWidget {
  const CustomerProfile({super.key});

  @override
  State<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfile> {
  final _supabase = Supabase.instance.client;
  
  String _fullName = 'Loading...';
  String _phone = 'Loading...';
  String _email = 'Loading...'; 
  String _loyaltyLevel = '...';
  String _userRole = '...';
  
  int _loyaltyPoints = 0;
  int _vehicleCount = 0;
  int _serviceRequestCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      if (userId == null) throw 'User not logged in';

      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final pointsData = await _supabase
          .from('loyalty_points')
          .select('points')
          .eq('profile_id', userId)
          .maybeSingle();

      final vehicleCount = await _supabase
          .from('vehicles')
          .count()
          .eq('profile_id', userId);

      final serviceCount = await _supabase
          .from('service_requests')
          .count()
          .eq('profile_id', userId);

      if (mounted) {
        setState(() {
          _email = user!.email ?? 'N/A';
          
          _fullName = profileData['full_name'] ?? 'N/A';
          _phone = profileData['phone'] ?? 'N/A';
          _loyaltyLevel = (profileData['loyalty_level'] as String? ?? 'BRONZE').toUpperCase();
          _userRole = (profileData['role'] as String? ?? 'CUSTOMER').toUpperCase();
          
          _loyaltyPoints = pointsData != null ? (pointsData['points'] as int) : 0;
          _vehicleCount = vehicleCount;
          _serviceRequestCount = serviceCount;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
        msg: 'Error loading data: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: ThemeColorManager.getSafeColor(),
        textColor: ThemeColorManager.getColor(),
        fontSize: 16.0,
      );
      }
    }
  }

  void _showEditSheet() {
    final nameController = TextEditingController(text: _fullName);
    final phoneController = TextEditingController(text: _phone);
    final formKey = GlobalKey<FormState>();
    final Color bgColor = ThemeColorManager.getColor();
    final Color textColor = ThemeColorManager.getSafeColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReadOnlyFieldSheet('Email', _email, Icons.email, textColor, bgColor),
                    const SizedBox(height: 16),
                    _buildEditTextField(
                      nameController,
                      'Full Name',
                      Icons.person,
                      textColor,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Name cannot be empty' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildEditTextField(
                      phoneController,
                      'Phone Number',
                      Icons.phone,
                      textColor,
                      validator: (value) =>
                          value == null || value.isEmpty || value.length < 5
                              ? 'Enter a valid phone number'
                              : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setModalState(() => isSaving = true);

                                  await _updateProfile(nameController.text, phoneController.text);

                                  if (mounted) {
                                    setModalState(() => isSaving = false);
                                    Navigator.pop(context);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: textColor,
                          foregroundColor: bgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: bgColor, 
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    Color textColor,
    {String? Function(String?)? validator}
  ) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: textColor.withAlpha(0xB3)),
        labelStyle: TextStyle(color: textColor.withAlpha(0xB3)),
        errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withAlpha(0x4D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withAlpha(0x4D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  Widget _buildReadOnlyFieldSheet(String label, String value, IconData icon, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: textColor.withAlpha(0x0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withAlpha(0x1A)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textColor.withAlpha(0x80)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: textColor.withAlpha(0x80), fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: textColor.withAlpha(0xCC), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: textColor.withAlpha(0x4D)),
        ],
      ),
    );
  }

  Future<void> _updateProfile(String name, String phone) async {
    if (!mounted) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('profiles').update({
        'full_name': name,
        'phone': phone,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        setState(() {
          _fullName = name;
          _phone = phone;
        });
        
        Fluttertoast.showToast(
          msg: 'Profile updated',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: ThemeColorManager.getSafeColor(),
          textColor: ThemeColorManager.getColor(),
          fontSize: 16.0,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to update profile',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.TOP,
          backgroundColor: ThemeColorManager.getSafeColor(),
          textColor: ThemeColorManager.getColor(),
          fontSize: 16.0,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = ThemeColorManager.getColor();
    final Color textColor = ThemeColorManager.getSafeColor();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        toolbarHeight: 80.0,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'My Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: IconButton(
              icon: Icon(Icons.edit_note, color: textColor, size: 30),
              onPressed: _isLoading ? null : _showEditSheet,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: textColor,
            height: 0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: textColor,
        backgroundColor: bgColor,
        child: _isLoading && _fullName == 'Loading...'
            ? Center(child: CircularProgressIndicator(color: textColor))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Primary Account', textColor),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: textColor.withAlpha(0x0D),
                        borderRadius: BorderRadius.circular(16),border: Border.all(color: Colors.grey, width: 1),
                        
                      ),
                      child: Column(
                        children: [
                          _buildInfoTile('Full Name', _fullName, Icons.person_outline, textColor),
                          _buildInfoTile('Email', _email, Icons.email_outlined, textColor),
                          _buildInfoTile('Phone', _phone, Icons.phone_outlined, textColor),
                          _buildInfoTile('Role', _userRole, Icons.badge_outlined, textColor, isLast: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Membership & Activity', textColor),
                    const SizedBox(height: 12),
                    
                    Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildFlexibleCard('Loyalty Points', _loyaltyPoints.toString(), Icons.loyalty, textColor)),
          const SizedBox(width: 16),
          Expanded(child: _buildFlexibleCard('Membership', _loyaltyLevel, Icons.star_border, textColor)),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildFlexibleCard('Vehicles Registered', _vehicleCount.toString(), Icons.directions_car_outlined, textColor)),
          const SizedBox(width: 16),
          Expanded(child: _buildFlexibleCard('Total Service Requests', _serviceRequestCount.toString(), Icons.build_outlined, textColor)),
        ],
      ),
    ],
  ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textColor.withAlpha(0x99),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color textColor, {bool isLast = false}) {
    final borderColor = textColor.withAlpha(0x1A);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: textColor.withAlpha(0xB3)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withAlpha(0x80),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
Widget _buildFlexibleCard(String title, String value, IconData icon, Color textColor) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: textColor.withAlpha(0x14),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: textColor.withAlpha(0x26), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textColor.withAlpha(0x26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: textColor, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: textColor.withAlpha(0xB3),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.2, 
          ),
        ),
      ],
    ),
  );
}

}