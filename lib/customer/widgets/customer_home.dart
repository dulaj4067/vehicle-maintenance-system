import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final supabase = Supabase.instance.client;
  String? userId;
  String fullName = '';
  List<Map<String, String>> offerData = [];
  String loyaltyLevel = 'bronze';
  List<Map<String, dynamic>> serviceData = [];
  bool isLoading = true;
  late PageController offersController;
  int currentPoints = 0;
  final List<Map<String, dynamic>> membershipData = [
    {
      'level': 'gold',
      'title': 'Gold',
      'color': Colors.amber.shade700,
      'subtitle': 'Earn points on every service',
      'icon': FontAwesomeIcons.solidStar,
    },
    {
      'level': 'silver',
      'title': 'Silver',
      'color': Colors.grey.shade700,
      'subtitle': 'Earn points on every service',
      'icon': FontAwesomeIcons.solidStar,
    },
    {
      'level': 'bronze',
      'title': 'Bronze',
      'color': const Color(0xFFCD7F32),
      'subtitle': 'Earn points on every service',
      'icon': FontAwesomeIcons.solidStar,
    },
  ];

  @override
  void initState() {
    super.initState();
    offersController = PageController(viewportFraction: 0.8);
    userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _loadData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    offersController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final DateTime now = DateTime.now();
      final String nowStr = now.toIso8601String().split('T')[0];

      final profileResponse = await supabase
          .from('profiles')
          .select('full_name, loyalty_level')
          .eq('id', userId!)
          .single();

      fullName = profileResponse['full_name'] ?? '';
      loyaltyLevel = profileResponse['loyalty_level'] ?? 'bronze';

      final pointsResponse = await supabase
      .from('loyalty_points')
      .select('points')
      .eq('profile_id', userId!)
      .maybeSingle();

      currentPoints = pointsResponse?['points'] ?? 0;

      final campaignsResponse = await supabase
          .from('campaigns')
          .select('title, content, image_url, start_date, end_date')
          .eq('is_active', true)
          .lte('start_date', nowStr)
          .gte('end_date', nowStr)
          .order('start_date');

      offerData = campaignsResponse.map((c) {
        return {
          'image': c['image_url'] as String? ?? 'https://picsum.photos/id/13/600/400',
          'title': c['title'] as String,
          'subtitle': 'Valid until ${c['end_date'] as String}',
        };
      }).toList();

      final servicesResponse = await supabase
          .from('service_requests')
          .select(
              'type, description, created_at, status, vehicles(make, model, year)')
          .eq('profile_id', userId!)
          .eq('status', 'pending')
          .order('created_at');

      serviceData = servicesResponse.map((s) {
        final String type = s['type'] ?? '';
        final String title = _getServiceTitle(type);
        final IconData icon = _getServiceIcon(type);
        final DateTime created = DateTime.parse(s['created_at']);
        final int daysAgo = now.difference(created).inDays;
        String subtitle;
        Color iconColor = Colors.black;
        if (daysAgo > 30) {
          subtitle = 'Overdue';
          iconColor = Colors.red;
        } else if (daysAgo > 7) {
          subtitle = 'Due soon';
        } else {
          subtitle = 'Recently requested';
        }
        return {
          'title': title,
          'subtitle': subtitle,
          'color': iconColor,
          'icon': icon,
          'vehicle': s['vehicles'],
          'description': s['description'] ?? '',
        };
      }).toList();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getServiceTitle(String type) {
    switch (type) {
      case 'oil_change':
        return 'Oil Change';
      case 'brake_inspection':
        return 'Brake Inspection';
      case 'tire_rotation':
        return 'Tire Rotation';
      case 'air_filter_replacement':
        return 'Air Filter Replacement';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getServiceIcon(String type) {
    switch (type) {
      case 'oil_change':
        return FontAwesomeIcons.oilCan;
      case 'brake_inspection':
        return FontAwesomeIcons.wrench;
      case 'tire_rotation':
        return FontAwesomeIcons.carSide;
      case 'air_filter_replacement':
        return FontAwesomeIcons.wind;
      default:
        return FontAwesomeIcons.screwdriverWrench;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }

    Map<String, dynamic>? currentMembership;
    for (var m in membershipData) {
      if (m['level'] == loyaltyLevel) {
        currentMembership = m;
        break;
      }
    }

    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          toolbarHeight: 80.0,
          title: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Hello, $fullName!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 10),
              color: Colors.black,
              height: 0.5,
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: Colors.black,
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Offers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (offerData.isEmpty)
                    Center(
                      child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.tag,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No offers available at the moment.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 200,
                            child: PageView.builder(
                              controller: offersController,
                              itemBuilder: (context, index) {
                                final int actualIndex =
                                    index % offerData.length;
                                return _buildOfferCard(
                                  offerData[actualIndex]['image']!,
                                  offerData[actualIndex]['title']!,
                                  offerData[actualIndex]['subtitle']!,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: offersController,
                            builder: (context, child) {
                              final double page =
                                  offersController.page ?? 0.0;
                              final int currentIndex =
                                  page.round() % offerData.length;
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                    offerData.length, (index) {
                                  return AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    height: 6,
                                    width: currentIndex == index ? 24 : 6,
                                    decoration: BoxDecoration(
                                      color: currentIndex == index
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : Colors.grey.shade300,
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 16),
                const Text(
                  'Membership',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (currentMembership != null)
                  _buildMembershipCard(
                    currentMembership['title']!,
                    currentMembership['color'] as Color,
                    currentMembership['subtitle']!,
                    currentMembership['icon'] as IconData,
                    true,
                    currentPoints,
                  ),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Services',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: serviceData.isEmpty
                          ? Center(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: const [
                                    FaIcon(
                                      FontAwesomeIcons.clipboardList,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No pending services.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          : ListView.separated(
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: serviceData.length,
                              itemBuilder: (context, index) {
                                final item = serviceData[index];
                                return _buildServiceTile(
                                  context,
                                  item['title']!,
                                  item['subtitle']!,
                                  item['color'] as Color,
                                  item['icon'] as IconData,
                                  item,
                                );
                              },
                              separatorBuilder: (context, index) {
                                return const Divider(
                                    height: 1, indent: 10, endIndent: 10);
                              },
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServiceDetailsDialog(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    IconData icon,
    Map<String, dynamic>? vehicle,
    String description,
  ) {
    final bool isOverdue = subtitle.contains('Overdue');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              FaIcon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isOverdue ? Colors.red.shade400 : Colors.grey.shade700,
                  fontWeight:
                      isOverdue ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              if (vehicle != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Vehicle',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle['make']} ${vehicle['model']} (${vehicle['year']})',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'This service for your vehicle is pending. Please book an appointment at your earliest convenience to keep your car in top condition.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMembershipCard(
    String title,
    Color color,
    String subtitle,
    IconData icon,
    bool isCurrent,
    int points,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? color : Colors.grey.shade300,
          width: isCurrent ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              radius: 20,
              child: FaIcon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: points / 100.0,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color.withValues()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$points / 100 points',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),          
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildOfferCard(
    String imageUrl,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.image,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTile(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    IconData icon,
    Map<String, dynamic> item,
  ) {
    final bool isOverdue = subtitle.contains('Overdue');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(25),
        child: FaIcon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isOverdue ? Colors.red.shade400 : Colors.grey.shade600,
          fontWeight: isOverdue ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: const FaIcon(
        FontAwesomeIcons.arrowRight,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {
        _showServiceDetailsDialog(
          context,
          title,
          subtitle,
          color,
          icon,
          item['vehicle'],
          item['description'],
        );
      },
    );
  }
}