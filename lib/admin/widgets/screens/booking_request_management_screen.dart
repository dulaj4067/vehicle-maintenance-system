import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingRequestManagementScreen extends StatefulWidget {
  const BookingRequestManagementScreen({super.key});

  @override
  State<BookingRequestManagementScreen> createState() =>
      _BookingRequestManagementScreenState();
}

class _BookingRequestManagementScreenState extends State<BookingRequestManagementScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> activeRequests = [];
  bool loadingPending = true;
  bool loadingActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPendingRequests();
    _loadActiveRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingRequests() async {
    if (!mounted) return;
    setState(() => loadingPending = true);

    try {
      final response = await supabase
          .from('service_requests')
          .select('''
            id, type, description, status, created_at, slot_id, suggested_slot_id,
            profile:profile_id (id, full_name, phone),
            vehicle:vehicle_id (make, model, year, number_plate),
            customer_slot:slot_id (
              id, date, start_time, end_time, service_type, is_available
            ),
            suggested_slot:suggested_slot_id (
              id, date, start_time, end_time, service_type, is_available
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        pendingRequests = List<Map<String, dynamic>>.from(response);
        loadingPending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingPending = false);
      _showSnackBar('Failed to load pending requests', Colors.red);
    }
  }

  Future<void> _loadActiveRequests() async {
    if (!mounted) return;
    setState(() => loadingActive = true);

    try {
      final response = await supabase
          .from('service_requests')
          .select('''
            id, type, description, status, created_at,
            profile:profile_id (id, full_name, phone),
            vehicle:vehicle_id (make, model, year, number_plate),
            slot:slot_id (id, date, start_time, end_time, service_type)
          ''')
          .inFilter('status', ['confirmed', 'cancelled', 'amended', 'completed'])
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        activeRequests = List<Map<String, dynamic>>.from(response);
        loadingActive = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingActive = false);
      _showSnackBar('Failed to load active requests', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _formatTo12Hour(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$hour:$minute $period';
  }

  Future<void> _suggestNewSlot(String requestId, Map<String, dynamic> request) async {
    final pickerContext = context;
    if (!mounted) return;
    
    final selectedDate = await showDatePicker(
      context: pickerContext,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1172D4),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (selectedDate == null || !mounted) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final slots = await supabase
        .from('time_slots')
        .select()
        .eq('date', dateStr)
        .eq('service_type', request['type'])
        .eq('is_available', true)
        .order('start_time');

    if (slots.isEmpty) {
      if (!mounted) return;
      _showSnackBar('No available slots on this date', Colors.orange);
      return;
    }

    final dialogContext = context;
    if (!mounted) return;
    
    final selectedSlot = await showDialog<Map<String, dynamic>?>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Suggest Alternative Slot'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final start = _formatTo12Hour(slot['start_time'].toString().substring(0, 5));
              final end = _formatTo12Hour(slot['end_time'].toString().substring(0, 5));
              return ListTile(
                title: Text('$start - $end'),
                subtitle: Text(DateFormat('EEEE, dd MMM yyyy').format(selectedDate)),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () => Navigator.pop(ctx, slot),
              );
            },
          ),
        ),
      ),
    );

    if (selectedSlot == null || !mounted) return;

    await supabase.from('service_requests').update({
      'suggested_slot_id': selectedSlot['id'],
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    await supabase.from('notifications').insert({
      'profile_id': request['profile']['id'],
      'type': 'offer',
      'title': 'New Time Suggested',
      'message': 'Admin suggested: ${_formatTo12Hour(selectedSlot['start_time'].substring(0, 5))} on ${DateFormat('dd MMM yyyy').format(selectedDate)}',
      'related_id': requestId,
    });

    if (!mounted) return;
    _showSnackBar('Slot suggested successfully!', Colors.green);
    _loadPendingRequests();
  }

  Future<void> _approveRequest(String requestId, String slotId) async {
    try {
      final slotCheck = await supabase
          .from('time_slots')
          .select('is_available')
          .eq('id', slotId)
          .single();

      if (!(slotCheck['is_available'] as bool)) {
        if (!mounted) return;
        _showSnackBar('This slot is no longer available', Colors.orange);
        _loadPendingRequests();
        return;
      }

      await supabase.from('service_requests').update({
        'status': 'confirmed',
        'slot_id': slotId,
        'suggested_slot_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      if (!mounted) return;
      _showSnackBar('Booking Confirmed Successfully!', Colors.green);
      _loadPendingRequests();
      _loadActiveRequests();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error confirming booking', Colors.red);
    }
  }

  Future<void> _completeAppointment(String requestId, Map<String, dynamic> request) async {
    final dialogContext = context;
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Complete Appointment'),
        content: const Text('Mark this appointment as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF1172D4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Send notification to customer
      await supabase.from('notifications').insert({
        'profile_id': request['profile']['id'],
        'type': 'confirmation',
        'title': 'Service Completed',
        'message': 'Your ${request['type']} service has been completed. Thank you for choosing our service!',
        'related_id': requestId,
      });

      if (!mounted) return;
      _showSnackBar('Appointment Completed Successfully!', Colors.green);
      _loadActiveRequests();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error completing appointment', Colors.red);
    }
  }

  Future<void> _rejectRequest(String requestId, String currentDesc) async {
    final reasonCtrl = TextEditingController();
    final dialogContext = context;
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF1172D4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final reason = reasonCtrl.text.trim();
    final newDesc = reason.isEmpty
        ? '$currentDesc\n\n[REJECTED by Admin]'
        : '$currentDesc\n\n[REJECTED] $reason';

    await supabase.from('service_requests').update({
      'status': 'cancelled',
      'description': newDesc,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    if (!mounted) return;
    _showSnackBar('Request Rejected', Colors.red);
    _loadPendingRequests();
  }

  Future<void> _cancelConfirmedRequest(String requestId) async {
    final dialogContext = context;
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cancel Appointment'),
        content: const Text('This will free the time slot. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF1172D4))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await supabase.from('service_requests').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    if (!mounted) return;
    _showSnackBar('Appointment Cancelled', Colors.orange);
    _loadActiveRequests();
  }

  void _showRequestDetails(Map<String, dynamic> request, {required bool isPending}) {
    final profile = request['profile'] as Map<String, dynamic>;
    final vehicle = request['vehicle'] as Map<String, dynamic>;
    final customerSlot = request['customer_slot'] as Map<String, dynamic>?;
    final suggestedSlot = request['suggested_slot'] as Map<String, dynamic>?;
    final confirmedSlot = request['slot'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: SizedBox(width: 60, height: 6, child: ColoredBox(color: Colors.grey))),
              const SizedBox(height: 20),
              Text(profile['full_name'] ?? 'Customer', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(profile['phone'] ?? '', style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Pure white card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Color(0xFF1172D4)),
                  title: Text('${vehicle['make']} ${vehicle['model']} ${vehicle['year'] ?? ''}'),
                  subtitle: Text('Plate: ${vehicle['number_plate'] ?? '—'}'),
                ),
              ),
              const SizedBox(height: 16),

              // Details card - pure white
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow('Type', (request['type'] as String).toUpperCase()),
                    if (customerSlot != null) _buildDetailRow('Customer Selected', '${customerSlot['date']} • ${_formatTo12Hour(customerSlot['start_time'].substring(0,5))}-${_formatTo12Hour(customerSlot['end_time'].substring(0,5))}', color: Colors.blue.shade700),
                    if (suggestedSlot != null) _buildDetailRow('Admin Suggested', '${suggestedSlot['date']} • ${_formatTo12Hour(suggestedSlot['start_time'].substring(0,5))}-${_formatTo12Hour(suggestedSlot['end_time'].substring(0,5))}', color: suggestedSlot['is_available'] ? Colors.green : Colors.red),
                    if (confirmedSlot != null) _buildDetailRow('Confirmed Slot', '${confirmedSlot['date']} • ${_formatTo12Hour(confirmedSlot['start_time'].substring(0,5))}-${_formatTo12Hour(confirmedSlot['end_time'].substring(0,5))}', color: Colors.green.shade700),
                    _buildDetailRow('Status', request['status'].toString().toUpperCase(), color: _getStatusColor(request['status'])),
                    if (request['description']?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(request['description']),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (isPending) ...[
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () { Navigator.pop(context); _rejectRequest(request['id'], request['description'] ?? ''); },
                      child: const Text('Reject', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () { Navigator.pop(context); _suggestNewSlot(request['id'], request); },
                      child: const Text('Suggest Alternative', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1172D4),
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (suggestedSlot?['is_available'] == true)
                      ? () { Navigator.pop(context); _approveRequest(request['id'], suggestedSlot!['id']); }
                      : (customerSlot?['is_available'] == true)
                          ? () { Navigator.pop(context); _approveRequest(request['id'], customerSlot!['id']); }
                          : null,
                  child: Text(
                    suggestedSlot?['is_available'] == true
                        ? 'Confirm Suggested Slot'
                        : customerSlot?['is_available'] == true
                            ? 'Confirm Customer Slot'
                            : 'No Available Slot',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ] else if (request['status'] == 'confirmed') ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () { Navigator.pop(context); _completeAppointment(request['id'], request); },
                  child: const Text('Complete Appointment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.all(18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () { Navigator.pop(context); _cancelConfirmedRequest(request['id']); },
                  child: const Text('Cancel Appointment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value, style: TextStyle(color: color ?? Colors.black87))),
          ],
        ),
      );

  Color _getStatusColor(String? status) => switch (status) {
        'confirmed' => Colors.green,
        'completed' => Colors.blue,
        'cancelled' => Colors.red,
        'pending' => Colors.orange,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.transparent,
          titleSpacing: 0,
          title: const SizedBox.shrink(),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicatorColor: const Color(0xFF1172D4),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Active / History'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending Tab
          loadingPending
              ? const Center(child: CircularProgressIndicator())
              : pendingRequests.isEmpty
                  ? const Center(child: Text('No pending requests', style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingRequests.length,
                      itemBuilder: (context, index) {
                        final r = pendingRequests[index];
                        final customerSlot = r['customer_slot'] as Map<String, dynamic>?;
                        final suggestedSlot = r['suggested_slot'] as Map<String, dynamic>?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showRequestDetails(r, isPending: true),
                            leading: CircleAvatar(
                              backgroundColor: customerSlot != null
                                  ? Colors.blue.withAlpha(30)
                                  : Colors.orange.withAlpha(30),
                              child: Icon(
                                customerSlot != null ? Icons.schedule_send : Icons.access_time,
                                color: customerSlot != null ? Colors.blue : Colors.orange,
                              ),
                            ),
                            title: Text('${r['profile']['full_name']} • ${(r['type'] as String).toUpperCase()}'),
                            subtitle: Text(
                              customerSlot != null
                                  ? '${DateFormat('dd MMM yyyy').format(DateTime.parse(customerSlot['date']))} • ${_formatTo12Hour(customerSlot['start_time'].substring(0,5))}'
                                  : suggestedSlot != null
                                      ? 'Suggested: ${suggestedSlot['date']} • ${_formatTo12Hour(suggestedSlot['start_time'].substring(0,5))}'
                                      : 'No slot selected',
                            ),
                            trailing: customerSlot != null
                                ? const Chip(
                                    label: Text('Customer Picked', style: TextStyle(fontSize: 10, color: Color(0xFF1172D4))),
                                    backgroundColor: Color(0xFFE3F2FD),
                                  )
                                : suggestedSlot != null
                                    ? Chip(
                                        label: Text(suggestedSlot['is_available'] ? 'Available' : 'Taken'),
                                        backgroundColor: suggestedSlot['is_available']
                                            ? Colors.green.withAlpha(40)
                                            : Colors.red.withAlpha(40),
                                      )
                                    : const Icon(Icons.schedule, color: Colors.grey),
                          ),
                        );
                      },
                    ),

          // Active Tab
          loadingActive
              ? const Center(child: CircularProgressIndicator())
              : activeRequests.isEmpty
                  ? const Center(child: Text('No active appointments', style: TextStyle(fontSize: 18, color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: activeRequests.length,
                      itemBuilder: (context, index) {
                        final r = activeRequests[index];
                        final slot = r['slot'] as Map<String, dynamic>?;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showRequestDetails(r, isPending: false),
                            leading: CircleAvatar(
                              backgroundColor: r['status'] == 'confirmed'
                                  ? Colors.green.withAlpha(30)
                                  : r['status'] == 'completed'
                                      ? Colors.blue.withAlpha(30)
                                      : Colors.red.withAlpha(30),
                              child: Icon(
                                r['status'] == 'confirmed'
                                    ? Icons.check_circle
                                    : r['status'] == 'completed'
                                        ? Icons.task_alt
                                        : Icons.cancel,
                                color: r['status'] == 'confirmed'
                                    ? Colors.green
                                    : r['status'] == 'completed'
                                        ? Colors.blue
                                        : Colors.red,
                              ),
                            ),
                            title: Text('${r['profile']['full_name']} • ${(r['type'] as String).toUpperCase()}'),
                            subtitle: slot != null
                                ? Text('${slot['date']} • ${_formatTo12Hour(slot['start_time'].substring(0,5))}-${_formatTo12Hour(slot['end_time'].substring(0,5))}')
                                : const Text('No slot assigned'),
                            trailing: Chip(
                              backgroundColor: _getStatusColor(r['status']).withAlpha(30),
                              label: Text(r['status'].toString().toUpperCase(), style: TextStyle(color: _getStatusColor(r['status']))),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}