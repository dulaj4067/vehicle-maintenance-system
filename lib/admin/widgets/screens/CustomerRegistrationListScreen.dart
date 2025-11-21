// lib/admin/screens/customer_registration_list_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

class CustomerRegistrationListScreen extends StatefulWidget {
  const CustomerRegistrationListScreen({super.key});

  @override
  State<CustomerRegistrationListScreen> createState() => _CustomerRegistrationListScreenState();
}

class _CustomerRegistrationListScreenState extends State<CustomerRegistrationListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pendingUsers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations();
  }

  Future<void> _loadPendingRegistrations() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final response = await supabase
          .rpc('get_pending_profiles_with_email')
          .select()
          .order('created_at', ascending: false);

      final List usersData = response as List;
      final List<Map<String, dynamic>> users = usersData.map((e) => e as Map<String, dynamic>).toList();

      if (!mounted) return;
      setState(() {
        pendingUsers = users;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateStatus(String userId, String status) async {
    try {
      await supabase.from('profiles').update({
        'status': status == 'approved' ? 'approved' : 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer ${status == 'approved' ? 'Approved' : 'Rejected'} Successfully'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        _loadPendingRegistrations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // SMART OPEN WITH BUCKET NAME FIX
  Future<void> _smartOpen(String url) async {
    // FIX OLD BUCKET NAMES IN URL
    String fixedUrl = url
        .replaceAll('customer-documents', 'customer_documents')
        .replaceAll('vehicle-documents', 'vehicle_documents');

    final extension = fixedUrl.split('.').last.toLowerCase().split('?').first;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
            body: PhotoView(
              imageProvider: NetworkImage(fixedUrl),
              loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error, color: Colors.red, size: 60)),
            ),
          ),
        ),
      );
    } else {
      if (!await launchUrl(Uri.parse(fixedUrl))) {
        throw 'Could not launch $fixedUrl';
      }
    }
  }

  void _showCustomerDetails(Map<String, dynamic> user) {
    List<Map<String, dynamic>> documentList = [];
    final rawDocs = user['documents'];
    if (rawDocs is List && rawDocs.isNotEmpty) {
      documentList = rawDocs.cast<Map<String, dynamic>>();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(user['full_name'] ?? 'No Name', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.person_outline, color: Color(0xFF1172D4), size: 24), SizedBox(width: 10), Text('Customer Details', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 16),
                    _infoRow(Icons.phone, user['phone'] ?? '—'),
                    const SizedBox(height: 10),
                    _infoRow(Icons.email_outlined, user['email'] ?? '—'),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              const Text('Verification Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              if (documentList.isEmpty)
                const Center(child: Text('No documents uploaded', style: TextStyle(color: Colors.grey, fontSize: 15)))
              else
                ...documentList.map((doc) {
                  final String type = doc['type'] ?? 'document';
                  final String url = doc['s3_link'] ?? '';
                  if (url.isEmpty) return const SizedBox();

                  // FINAL FIX FOR BUCKET NAME
                  final String fixedUrl = url
                      .replaceAll('customer-documents', 'customer_documents')
                      .replaceAll('vehicle-documents', 'vehicle_documents');

                  return _buildDocumentCard(_formatDocType(type), fixedUrl);
                }),

              const SizedBox(height: 60),
              Row(
                children: [
                  Expanded(child: _rejectButton(user)),
                  const SizedBox(width: 16),
                  Expanded(child: _approveButton(user)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [Icon(icon, size: 20, color: Colors.grey[600]), const SizedBox(width: 12), Text(text, style: const TextStyle(fontSize: 16.5))]);

  Widget _buildDocumentCard(String title, String url) {
    final extension = url.split('.').last.toLowerCase().split('?').first;
    final fileName = url.split('/').last.split('?').first;

    IconData icon = Icons.description;
    Color iconColor = Colors.grey.shade700;

    if (extension == 'pdf') {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red.shade600;
    } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      icon = Icons.image;
      iconColor = Colors.blue.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.12), child: Icon(icon, color: iconColor, size: 28)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(fileName, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => _smartOpen(url), tooltip: 'View'),
            IconButton(icon: const Icon(Icons.download, color: Colors.green), onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), tooltip: 'Download'),
          ],
        ),
      ),
    );
  }

  Widget _rejectButton(Map<String, dynamic> user) => SizedBox(
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6),
      onPressed: () { Navigator.pop(context); _confirmAction(user['id'] as String, 'rejected', user); },
      child: const Text('Reject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
    ),
  );

  Widget _approveButton(Map<String, dynamic> user) => SizedBox(
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6),
      onPressed: () { Navigator.pop(context); _confirmAction(user['id'] as String, 'approved', user); },
      child: const Text('Approve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
    ),
  );

  String _formatDocType(String type) => type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  void _confirmAction(String id, String status, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${status == 'approved' ? 'Approve' : 'Reject'} Customer?'),
        content: Text('Name: ${user['full_name']}\nPhone: ${user['phone']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: status == 'approved' ? Colors.green : Colors.red),
            onPressed: () { Navigator.pop(context); _updateStatus(id, status); },
            child: Text(status == 'approved' ? 'Approve' : 'Reject', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => context.pop()),
        title: const Text('Pending Customer Registrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
          : pendingUsers.isEmpty
              ? const Center(child: Text('No pending registrations', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingUsers.length,
                  itemBuilder: (_, i) {
                    final user = pendingUsers[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _showCustomerDetails(user),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.person_outline, size: 44, color: Color(0xFF1172D4))),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user['full_name'] ?? 'No Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(user['phone'] ?? '—', style: TextStyle(color: Colors.grey[700], fontSize: 15.5)),
                                    const SizedBox(height: 4),
                                    Text(user['email'] ?? '—', style: TextStyle(color: Colors.grey[600], fontSize: 14.5)),
                                    const SizedBox(height: 14),
                                    const Text('Tap to view details', style: TextStyle(color: Color(0xFF1172D4), fontSize: 14.5, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}