// lib/admin/screens/vehicle_registration_list_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart'; // ADD THIS DEPENDENCY

class VehicleRegistrationListScreen extends StatefulWidget {
  const VehicleRegistrationListScreen({super.key});

  @override
  State<VehicleRegistrationListScreen> createState() => _VehicleRegistrationListScreenState();
}

class _VehicleRegistrationListScreenState extends State<VehicleRegistrationListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pendingVehicles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingVehicles();
  }

  Future<void> _loadPendingVehicles() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final response = await supabase.rpc('get_pending_vehicles_with_owner').select();

      if (!mounted) return;
      setState(() {
        pendingVehicles = List<Map<String, dynamic>>.from(response);
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

  Future<void> _updateStatus(String id, String status) async {
    try {
      await supabase.from('vehicles').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehicle ${status == 'approved' ? 'Approved' : 'Rejected'}'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        _loadPendingVehicles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // SMART OPEN: Images in PhotoView, others in external app
  Future<void> _smartOpen(String url) async {
    final extension = url.split('.').last.toLowerCase().split('?').first;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
            body: PhotoView(
              imageProvider: NetworkImage(url),
              loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error, color: Colors.red, size: 60)),
            ),
          ),
        ),
      );
    } else {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showVehicleDetails(Map<String, dynamic> v) {
    // Parse documents array from JSONB
    List<Map<String, dynamic>> documentList = [];
    final rawDocs = v['documents'];
    if (rawDocs is Map && rawDocs.isNotEmpty) {
      // Handle both object and array formats
      if (rawDocs.containsKey('registration_doc_url')) {
        if (rawDocs['registration_doc_url'] != null)
          documentList.add({'type': 'registration_doc', 's3_link': rawDocs['registration_doc_url']});
        if (rawDocs['insurance_doc_url'] != null)
          documentList.add({'type': 'insurance_doc', 's3_link': rawDocs['insurance_doc_url']});
      }
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

              Text('${v['make']} ${v['model']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text('${v['year']}', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // OWNER CARD
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
                    const Row(children: [
                      Icon(Icons.person_outline, color: Color(0xFF1172D4), size: 24),
                      SizedBox(width: 10),
                      Text('Vehicle Owner', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold))
                    ]),
                    const SizedBox(height: 16),
                    _infoRow(Icons.account_circle, v['owner_full_name'] ?? '—'),
                    _infoRow(Icons.phone, v['owner_phone'] ?? '—'),
                    _infoRow(Icons.email_outlined, v['owner_email'] ?? '—'),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),

              _infoRowBold('Number Plate', v['number_plate'] ?? '—'),
              _infoRowBold('Color', (v['color']?.toString().split('.').last ?? 'Not specified').toTitleCase()),

              const SizedBox(height: 32),
              const Text('Verification Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              if (documentList.isEmpty)
                const Center(child: Text('No documents uploaded', style: TextStyle(color: Colors.grey, fontSize: 15)))
              else
                ...documentList.map((doc) {
                  final String type = doc['type'] ?? 'document';
                  final String url = doc['s3_link'] ?? '';
                  if (url.isEmpty) return const SizedBox();
                  return _buildDocumentCard(_formatDocType(type), url);
                }),

              const SizedBox(height: 60),
              Row(
                children: [
                  Expanded(child: _rejectButton(v)),
                  const SizedBox(width: 16),
                  Expanded(child: _approveButton(v)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16.5))),
        ]),
      );

  Widget _infoRowBold(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ]),
      );

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

  String _formatDocType(String type) {
    final map = {
      'registration_doc': 'Registration Document',
      'insurance_doc': 'Insurance Document',
    };
    return map[type] ?? type.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Widget _rejectButton(Map v) => SizedBox(
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6),
      onPressed: () { Navigator.pop(context); _confirm('rejected', v); },
      child: const Text('Reject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
    ),
  );

  Widget _approveButton(Map v) => SizedBox(
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6),
      onPressed: () { Navigator.pop(context); _confirm('approved', v); },
      child: const Text('Approve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
    ),
  );

  void _confirm(String status, Map v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${status == 'approved' ? 'Approve' : 'Reject'} Vehicle?'),
        content: Text('${v['make']} ${v['model']} ${v['year']}\nPlate: ${v['number_plate']}\nOwner: ${v['owner_full_name']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: status == 'approved' ? Colors.green : Colors.red),
            onPressed: () { Navigator.pop(context); _updateStatus(v['id'], status); },
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
        title: const Text('Pending Vehicle Registrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
          : pendingVehicles.isEmpty
              ? const Center(child: Text('No pending vehicles', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingVehicles.length,
                  itemBuilder: (_, i) {
                    final v = pendingVehicles[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _showVehicleDetails(v),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(children: [
                            Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.directions_car, size: 44, color: Color(0xFF1172D4))),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${v['make']} ${v['model']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text('Year: ${v['year']}', style: TextStyle(color: Colors.grey[700], fontSize: 15.5)),
                                const SizedBox(height: 4),
                                Text(v['number_plate'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1172D4))),
                                const SizedBox(height: 8),
                                Text(v['owner_full_name'], style: const TextStyle(fontSize: 14.5)),
                                const SizedBox(height: 12),
                                const Text('Tap to view details', style: TextStyle(color: Color(0xFF1172D4), fontSize: 14.5, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

extension StringExt on String {
  String toTitleCase() => split('_').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}