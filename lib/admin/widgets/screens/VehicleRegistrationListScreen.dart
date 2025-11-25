// lib/admin/screens/vehicle_registration_list_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

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
        SnackBar(content: Text('Error loading vehicles: $e'), backgroundColor: Colors.red),
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
            content: Text('Vehicle ${status == 'approved' ? 'Approved' : 'Rejected'} Successfully'),
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

  Future<void> _smartOpen(String url) async {
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
              loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.error, color: Colors.red, size: 60)),
            ),
          ),
        ),
      );
    } else {
      await launchUrl(Uri.parse(fixedUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _showVehicleDetails(Map<String, dynamic> v) {
    List<Map<String, dynamic>> documentList = [];

    final rawDocs = v['documents'];
    if (rawDocs != null) {
      if (rawDocs is List) {
        for (var doc in rawDocs) {
          if (doc is Map<String, dynamic>) {
            final type = (doc['type'] ?? 'document').toString().toLowerCase();
            final url = doc['url']?.toString() ?? doc['s3_link']?.toString() ?? '';
            if (url.isNotEmpty) documentList.add({'type': type, 'url': url});
          }
        }
      } else if (rawDocs is Map<String, dynamic>) {
        rawDocs.forEach((key, value) {
          if (value is String && value.isNotEmpty) {
            documentList.add({'type': key, 'url': value});
          } else if (value is Map<String, dynamic>) {
            final url = value['url']?.toString() ?? value['s3_link']?.toString() ?? '';
            if (url.isNotEmpty) documentList.add({'type': key, 'url': url});
          }
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.97,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              const _DragHandle(),
              const SizedBox(height: 20),
              Text('${v['make']} ${v['model']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text('${v['year']}', style: TextStyle(fontSize: 18, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Owner Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.person_outline, color: Color(0xFF1172D4), size: 26),
                      SizedBox(width: 12),
                      Text('Vehicle Owner', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    ]),
                    SizedBox(height: 16),
                    _infoRow(Icons.account_circle, v['owner_full_name'] ?? '—'),
                    _infoRow(Icons.phone, v['owner_phone'] ?? '—'),
                    _infoRow(Icons.email_outlined, v['owner_email'] ?? '—'),
                  ],
                ),
              ),

              SizedBox(height: 32),
              Divider(height: 1, color: Color(0xFFE5E7EB)),
              SizedBox(height: 16),

              _infoRowBold('Number Plate', v['number_plate']?.toString().toUpperCase() ?? '—'),
              _infoRowBold('Color', (v['color']?.toString().split('.').last ?? 'Not specified').toTitleCase()),

              SizedBox(height: 32),
              Text('Verification Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),

              documentList.isEmpty
                  ? _EmptyDocumentsState()
                  : Column(children: documentList.map((doc) {
                      final fixedUrl = doc['url']
                          .toString()
                          .replaceAll('customer-documents', 'customer_documents')
                          .replaceAll('vehicle-documents', 'vehicle_documents');
                      return _buildDocumentCard(_formatDocType(doc['type']), fixedUrl);
                    }).toList()),

              SizedBox(height: 60),
              Row(children: [
                Expanded(child: _rejectButton(v)),
                SizedBox(width: 16),
                Expanded(child: _approveButton(v)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 22, color: Colors.grey[600]),
          SizedBox(width: 14),
          Expanded(child: Text(text, style: TextStyle(fontSize: 16.5))),
        ]),
      );

  Widget _infoRowBold(String label, String value) => Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _buildDocumentCard(String title, String url) {
    final extension = url.split('.').last.toLowerCase().split('?').first;
    final fileName = url.split('/').last.split('?').first;

    IconData icon = Icons.description;
    Color color = Colors.grey.shade700;
    if (extension == 'pdf') {
      icon = Icons.picture_as_pdf;
      color = Colors.red.shade600;
    } else if (['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      icon = Icons.image;
      color = Colors.blue.shade600;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 28)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(padding: EdgeInsets.only(top: 4), child: Text(fileName, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: Icon(Icons.visibility, color: Colors.blue), onPressed: () => _smartOpen(url), tooltip: 'View'),
            IconButton(icon: Icon(Icons.download, color: Colors.green), onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), tooltip: 'Download'),
          ],
        ),
      ),
    );
  }

  String _formatDocType(String type) {
    final map = {
      'rc_book': 'RC Book',
      'insurance': 'Insurance Document',
      'pollution_certificate': 'Pollution Certificate',
      'registration_doc': 'Registration Document',
      'insurance_doc': 'Insurance Document',
    };
    return map[type] ?? type.split('_').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Widget _rejectButton(Map v) => SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8),
          onPressed: () {
            Navigator.pop(context);
            _confirmAction('rejected', v);
          },
          child: Text('Reject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );

  Widget _approveButton(Map v) => SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8),
          onPressed: () {
            Navigator.pop(context);
            _confirmAction('approved', v);
          },
          child: Text('Approve', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      );

  void _confirmAction(String status, Map v) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${status == 'approved' ? 'Approve' : 'Reject'} Vehicle Registration?'),
        content: Text.rich(TextSpan(children: [
          TextSpan(text: 'Vehicle: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: '${v['make']} ${v['model']} (${v['year']})\n'),
          TextSpan(text: 'Plate: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: '${v['number_plate']}\n'),
          TextSpan(text: 'Owner: ', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: v['owner_full_name']),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Color(0xFF1172D4)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: status == 'approved' ? Colors.green : Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(v['id'], status);
            },
            child: Text(status == 'approved' ? 'Approve' : 'Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => context.pop()),
        title: Text('Pending Vehicle Registrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
        centerTitle: true,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
          : pendingVehicles.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No pending registrations',
                          style: TextStyle(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'All vehicle registrations have been processed.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingVehicles,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: pendingVehicles.length,
                    itemBuilder: (_, i) {
                      final v = pendingVehicles[i];
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: Offset(0, 8))],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _showVehicleDetails(v),
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Row(children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(color: Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(20)),
                                child: Icon(Icons.directions_car, size: 44, color: Color(0xFF1172D4)),
                              ),
                              SizedBox(width: 20),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${v['make']} ${v['model']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text('Year: ${v['year']}', style: TextStyle(color: Colors.grey[700], fontSize: 15.5)),
                                  SizedBox(height: 6),
                                  Text(v['number_plate'] ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1172D4))),
                                  SizedBox(height: 8),
                                  Text(v['owner_full_name'] ?? '', style: TextStyle(fontSize: 15)),
                                  SizedBox(height: 12),
                                  Text('Tap to review documents →', style: TextStyle(color: Color(0xFF1172D4), fontSize: 15, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Reusable const widgets
class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
      );
}

class _EmptyDocumentsState extends StatelessWidget {
  const _EmptyDocumentsState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No documents uploaded', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ]),
        ),
      );
}

extension StringExt on String {
  String toTitleCase() => split('_').map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
}