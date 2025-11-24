// lib/admin/widgets/admin_home.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  Widget _metricCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    String? subtitle,
  ]) {
    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          ),
                          _metricCard(
                            "Approved Vehicles",
                            totalApprovedVehicles.toString(),
                            Icons.directions_car,
                            Colors.teal,
                          ),
                          _metricCard(
                            "Today's Bookings",
                            totalBookingsToday.toString(),
                            Icons.event_available,
                            Colors.green,
                          ),
                          _metricCard(
                            "Pending Requests",
                            pendingRequests.toString(),
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                          _metricCard(
                            "Active Campaigns",
                            activeCampaigns.toString(),
                            Icons.campaign,
                            Colors.purple,
                          ),
                          _metricCard(
                            "Services This Month",
                            servicesThisMonth.toString(),
                            Icons.check_circle,
                            Colors.indigo,
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