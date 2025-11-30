// lib/admin/widgets/admin_home.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Navigation callback key for accessing parent navigation
class AdminNavigationController {
  static void Function(int)? onNavigate;
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final supabase = Supabase.instance.client;

  int totalCustomers = 0;
  int newCustomersThisMonth = 0;
  int totalBookingsToday = 0;
  int pendingRequests = 0;
  int servicesThisMonth = 0;
  int activeCampaigns = 0;
  int totalApprovedVehicles = 0;
  List<int> weeklyServices = List.filled(7, 0);
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Parallel execution of all main queries
      final results = await Future.wait([
        // 0: Total customers
        supabase.from('profiles').select('id').eq('role', 'customer'),
        
        // 1: New customers this month
        supabase
            .from('profiles')
            .select('id')
            .eq('role', 'customer')
            .gte('created_at', startOfMonth.toIso8601String()),
        
        // 2: Today's completed bookings
        supabase
            .from('service_requests')
            .select('id')
            .eq('status', 'completed')
            .gte('created_at', startOfToday.toIso8601String()),
        
        // 3: Pending requests
        supabase.from('service_requests').select('id').eq('status', 'pending'),
        
        // 4: Completed services this month
        supabase
            .from('service_requests')
            .select('id')
            .eq('status', 'completed')
            .gte('updated_at', startOfMonth.toIso8601String()),
        
        // 5: Active campaigns
        supabase.from('campaigns').select('id').eq('is_active', true),
        
        // 6: Approved vehicles
        supabase.from('vehicles').select('id').eq('status', 'approved'),
      ]);

      // Weekly data - parallel execution for all 7 days
      final weekStart = now.subtract(const Duration(days: 6));
      final weekEnd = now.add(const Duration(days: 1));
      
      // Fetch all completed services for the week in one query
      final weeklyResponse = await supabase
          .from('service_requests')
          .select('id, created_at')
          .eq('status', 'completed')
          .gte('created_at', DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String())
          .lt('created_at', DateTime(weekEnd.year, weekEnd.month, weekEnd.day).toIso8601String());

      // Group services by day
      final weekly = List.filled(7, 0);
      for (var service in (weeklyResponse as List)) {
        final createdAt = DateTime.parse(service['created_at']);
        final daysDiff = now.difference(DateTime(createdAt.year, createdAt.month, createdAt.day)).inDays;
        if (daysDiff >= 0 && daysDiff <= 6) {
          weekly[6 - daysDiff]++;
        }
      }

      if (mounted) {
        setState(() {
          totalCustomers = (results[0] as List).length;
          newCustomersThisMonth = (results[1] as List).length;
          totalBookingsToday = (results[2] as List).length;
          pendingRequests = (results[3] as List).length;
          servicesThisMonth = (results[4] as List).length;
          activeCampaigns = (results[5] as List).length;
          totalApprovedVehicles = (results[6] as List).length;
          weeklyServices = weekly;
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Admin dashboard error: $e\n$stackTrace');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showTodaysBookings() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      
      final bookings = await supabase
          .from('service_requests')
          .select('''
            id, type, description, status, created_at,
            profile:profile_id (id, full_name, phone),
            vehicle:vehicle_id (make, model, year, number_plate),
            slot:slot_id (id, date, start_time, end_time, service_type)
          ''')
          .eq('status', 'completed')
          .gte('created_at', startOfToday.toIso8601String())
          .order('created_at', ascending: false);

      if (!mounted) return;

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 60,
                          height: 6,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Today's Bookings",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${bookings.length} Completed Today',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bookings.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_available, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No bookings completed today',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final booking = bookings[index];
                            final profile = booking['profile'] as Map<String, dynamic>?;
                            final vehicle = booking['vehicle'] as Map<String, dynamic>?;
                            final slot = booking['slot'] as Map<String, dynamic>?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.green.withAlpha(30),
                                          child: const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile?['full_name'] ?? 'Unknown Customer',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (profile?['phone'] != null)
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.phone,
                                                      size: 12,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      profile!['phone'],
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withAlpha(30),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            (booking['type'] as String).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    if (vehicle != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${vehicle['make']} ${vehicle['model']} ${vehicle['year'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (vehicle['number_plate'] != null)
                                        Row(
                                          children: [
                                            const SizedBox(width: 24),
                                            Text(
                                              'Plate: ${vehicle['number_plate']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                    if (slot != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_formatTo12Hour(slot['start_time'].substring(0, 5))} - ${_formatTo12Hour(slot['end_time'].substring(0, 5))}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (booking['description']?.isNotEmpty == true) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.notes, size: 16, color: Colors.grey),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              booking['description'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading today\'s bookings: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load today\'s bookings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showServicesThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final services = await supabase
          .from('service_requests')
          .select('''
            id, type, description, status, created_at, updated_at,
            profile:profile_id (id, full_name, phone),
            vehicle:vehicle_id (make, model, year, number_plate),
            slot:slot_id (id, date, start_time, end_time, service_type)
          ''')
          .eq('status', 'completed')
          .gte('updated_at', startOfMonth.toIso8601String())
          .order('updated_at', ascending: false);

      if (!mounted) return;

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 60,
                          height: 6,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Services This Month',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${services.length} Completed in ${DateFormat('MMMM yyyy').format(now)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: services.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No services completed this month',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final profile = service['profile'] as Map<String, dynamic>?;
                            final vehicle = service['vehicle'] as Map<String, dynamic>?;
                            final slot = service['slot'] as Map<String, dynamic>?;
                            final completedDate = DateTime.parse(service['updated_at']);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Colors.indigo.withAlpha(30),
                                          child: const Icon(
                                            Icons.check_circle,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile?['full_name'] ?? 'Unknown Customer',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_today,
                                                    size: 11,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Completed: ${DateFormat('dd MMM, hh:mm a').format(completedDate)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withAlpha(30),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            (service['type'] as String).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (vehicle != null) ...[
                                                Row(
                                                  children: [
                                                    const Icon(Icons.directions_car, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${vehicle['make']} ${vehicle['model']} ${vehicle['year'] ?? ''}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              if (profile?['phone'] != null)
                                                Row(
                                                  children: [
                                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      profile!['phone'],
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (vehicle?['number_plate'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1172D4).withAlpha(20),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              vehicle!['number_plate'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Color(0xFF1172D4),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (slot != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Service Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(slot['date']))}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_formatTo12Hour(slot['start_time'].substring(0, 5))} - ${_formatTo12Hour(slot['end_time'].substring(0, 5))}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (service['description']?.isNotEmpty == true) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.notes, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                service['description'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading services this month: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load services'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTo12Hour(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$hour:$minute $period';
  }

  Future<void> _showAllCustomers() async {
    try {
      final customers = await supabase
          .from('profiles')
          .select('id, full_name, phone, loyalty_level, created_at')
          .eq('role', 'customer')
          .order('created_at', ascending: false);

      if (!mounted) return;

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 60,
                          height: 6,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'All Customers',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${customers.length} Total Customers',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      final loyaltyLevel = customer['loyalty_level'].toString();
                      final tierColor = loyaltyLevel == 'gold'
                          ? Colors.amber
                          : loyaltyLevel == 'silver'
                              ? Colors.grey
                              : const Color(0xFFCD7F32);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: tierColor.withAlpha(30),
                            child: Icon(Icons.person, color: tierColor),
                          ),
                          title: Text(
                            customer['full_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(customer['phone'] ?? 'No phone'),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(customer['created_at']))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(
                              loyaltyLevel.toUpperCase(),
                              style: TextStyle(
                                color: tierColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: tierColor.withAlpha(40),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading customers: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load customers'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAllVehicles() async {
    try {
      final vehicles = await supabase
          .from('vehicles')
          .select('id, make, model, year, number_plate, color, created_at, profile:profile_id(full_name, phone)')
          .eq('status', 'approved')
          .order('created_at', ascending: false);

      if (!mounted) return;

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 60,
                          height: 6,
                          child: ColoredBox(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Approved Vehicles',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${vehicles.length} Total Vehicles',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final profile = vehicle['profile'] as Map<String, dynamic>?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.teal.withAlpha(30),
                                    child: const Icon(
                                      Icons.directions_car,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile?['full_name'] ?? 'Unknown Owner',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (profile?['phone'] != null)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.phone,
                                                size: 12,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                profile!['phone'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${vehicle['make']} ${vehicle['model']}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Year: ${vehicle['year'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (vehicle['color'] != null)
                                          Text(
                                            'Color: ${vehicle['color']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1172D4).withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      vehicle['number_plate'] ?? 'No Plate',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1172D4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load vehicles'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToScreen(int index) {
    AdminNavigationController.onNavigate?.call(index);
  }

  Widget _metricCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    String? subtitle,
    VoidCallback? onTap,
  ]) {
    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const Spacer(),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxBar = weeklyServices.isEmpty
        ? 1.0
        : weeklyServices.reduce((a, b) => a > b ? a : b).toDouble();

    final width = MediaQuery.of(context).size.width;
    final aspect = width < 380 ? 2.0 : 2.3;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
          : Container(
              color: Colors.white,
              child: RefreshIndicator(
                color: const Color(0xFF1172D4),
                backgroundColor: Colors.white,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: aspect,
                        children: [
                          _metricCard(
                            "Total Customers",
                            totalCustomers.toString(),
                            Icons.people_alt,
                            Colors.blue,
                            "+$newCustomersThisMonth new",
                            _showAllCustomers,
                          ),
                          _metricCard(
                            "Approved Vehicles",
                            totalApprovedVehicles.toString(),
                            Icons.directions_car,
                            Colors.teal,
                            null,
                            _showAllVehicles,
                          ),
                          _metricCard(
                            "Today's Bookings",
                            totalBookingsToday.toString(),
                            Icons.event_available,
                            Colors.green,
                            null,
                            _showTodaysBookings,
                          ),
                          _metricCard(
                            "Pending Requests",
                            pendingRequests.toString(),
                            Icons.pending_actions,
                            Colors.orange,
                            null,
                            () => _navigateToScreen(3), // Navigate to Booking Requests
                          ),
                          _metricCard(
                            "Active Campaigns",
                            activeCampaigns.toString(),
                            Icons.campaign,
                            Colors.purple,
                            null,
                            () => _navigateToScreen(4), // Navigate to Marketing Campaigns
                          ),
                          _metricCard(
                            "Services This Month",
                            servicesThisMonth.toString(),
                            Icons.check_circle,
                            Colors.indigo,
                            null,
                            _showServicesThisMonth,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Card(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Weekly Services & Maintenance',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 160,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: List.generate(7, (i) {
                                    final count = weeklyServices[i];
                                    final height = maxBar > 0 ? (count / maxBar) * 110 : 0.0;
                                    final dayLabel = DateFormat('E').format(
                                        DateTime.now().subtract(Duration(days: 6 - i)));
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1172D4),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(count.toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text(dayLabel,
                                            style:
                                                const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}