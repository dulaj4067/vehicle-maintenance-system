// lib/admin/screens/booking_request_management_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingRequestManagementScreen extends StatefulWidget {
  const BookingRequestManagementScreen({super.key});

  @override
  State<BookingRequestManagementScreen> createState() => _BookingRequestManagementScreenState();
}

class _BookingRequestManagementScreenState extends State<BookingRequestManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> requests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('service_requests')
          .select('''
            id,
            type,
            description,
            status,
            created_at,
            suggested_slot_id,
            profile:profile_id (full_name, phone),
            vehicle:vehicle_id (make, model, year, number_plate, color),
            suggested_slot:suggested_slot_id (
              id,
              date,
              start_time,
              end_time,
              service_type,
              is_available
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        requests = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Failed to load requests'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approveRequest(String requestId, Map<String, dynamic> slot) async {
    if (!(slot['is_available'] as bool? ?? false)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot is no longer available'), backgroundColor: Colors.orange),
      );
      _loadPendingRequests();
      return;
    }

    try {
      await supabase.from('service_requests').update({
        'status': 'confirmed',
        'slot_id': slot['id'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking Confirmed Successfully!'), backgroundColor: Colors.green),
      );
      _loadPendingRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(String requestId, String currentDescription) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Booking Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Reason (optional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final reason = reasonController.text.trim();
    final newDescription = reason.isEmpty
        ? '$currentDescription\n\n[REJECTED by Admin]'
        : '$currentDescription\n\n[REJECTED] $reason';

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled',
        'description': newDescription,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      if (!mounted) return;

      // LIGHT RED SNACKBAR — FIXED const error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request Rejected', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.red.shade100,  // Now works perfectly
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );
      _loadPendingRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final profile = request['profile'] as Map<String, dynamic>;
    final vehicle = request['vehicle'] as Map<String, dynamic>;
    final slot = request['suggested_slot'] as Map<String, dynamic>?;
    final isAvailable = slot?['is_available'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            children: [
              Center(child: Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text(profile['full_name'] ?? 'Customer', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(profile['phone'] ?? '', style: TextStyle(fontSize: 18, color: Colors.grey[700]), textAlign: TextAlign.center),
              const SizedBox(height: 32),

              Card(color: Colors.white, elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.directions_car, color: Color(0xFF1172D4), size: 28), SizedBox(width: 12), Text('Vehicle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                const Divider(height: 32),
                Text('${vehicle['make']} ${vehicle['model']} ${vehicle['year'] ?? ''}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Plate: ${vehicle['number_plate'] ?? '—'}', style: TextStyle(color: Colors.grey[700], fontSize: 16)),
              ]))),

              const SizedBox(height: 24),

              Card(color: Colors.white, elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.build_circle, color: Color(0xFF1172D4), size: 28), SizedBox(width: 12), Text('Service Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
                const Divider(height: 32),
                _row('Type', (request['type'] as String?)?.toUpperCase() ?? 'UNKNOWN'),
                _row('Requested', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(request['created_at'] as String))),
                if (slot != null) ...[
                  _row('Date', DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(slot['date'] as String))),
                  _row('Time', '${slot['start_time'].toString().substring(0,5)} - ${slot['end_time'].toString().substring(0,5)}'),
                  _row('Status', isAvailable ? 'Available' : 'Booked', color: isAvailable ? Colors.green : Colors.red),
                ],
                const SizedBox(height: 16),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(request['description']?.toString() ?? 'No description', style: const TextStyle(fontSize: 16)),
              ]))),

              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, padding: const EdgeInsets.all(18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () { Navigator.pop(context); _rejectRequest(request['id'] as String, request['description']?.toString() ?? ''); },
                      child: const Text('Reject Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isAvailable ? const Color(0xFF1172D4) : Colors.grey, padding: const EdgeInsets.all(18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: isAvailable ? () { Navigator.pop(context); _approveRequest(request['id'] as String, slot!); } : null,
                      child: Text(isAvailable ? 'Confirm Booking' : 'Slot Taken', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 16),
            Expanded(child: Text(value, style: TextStyle(color: color ?? Colors.black87, fontSize: 16))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: null,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
            : requests.isEmpty
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 80, color: Colors.grey), SizedBox(height: 16), Text('No pending requests', style: TextStyle(fontSize: 18, color: Colors.grey))]))
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: requests.length,
                    itemBuilder: (_, i) {
                      final r = requests[i];
                      final p = r['profile'] as Map<String, dynamic>;
                      final v = r['vehicle'] as Map<String, dynamic>;
                      final s = r['suggested_slot'] as Map<String, dynamic>?;

                      return Card(
                        color: Colors.white,
                        elevation: 10,
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _showRequestDetails(r),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                CircleAvatar(radius: 30, backgroundColor: const Color(0xFFF0F7FF), child: const Icon(Icons.person, color: Color(0xFF1172D4))),
                                const SizedBox(width: 16),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p['full_name'] ?? 'Customer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text(p['phone'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                                ])),
                                Chip(backgroundColor: Colors.orange.shade50, label: Text((r['type'] as String?)?.toUpperCase() ?? 'SERVICE', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold))),
                              ]),
                              const SizedBox(height: 16),
                              Row(children: [const Icon(Icons.directions_car, size: 20), const SizedBox(width: 8), Text('${v['make']} ${v['model']} • ${v['number_plate']}')]),
                              if (s != null) ...[const SizedBox(height: 10), Row(children: [const Icon(Icons.calendar_today, size: 20), const SizedBox(width: 8), Text('${DateFormat('dd MMM yyyy').format(DateTime.parse(s['date']))} • ${s['start_time'].substring(0,5)} - ${s['end_time'].substring(0,5)}')])],
                              const SizedBox(height: 12),
                              Text(r['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700])),
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