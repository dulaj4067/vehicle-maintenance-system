import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme_color.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Vehicle {
  final String id;
  final String make;
  final String model;
  final int year;
  final String numberPlate;
  final String? color;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.numberPlate,
    this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      numberPlate: json['number_plate'],
      color: json['color'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TimeSlot {
  final String id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String serviceType;
  final bool isAvailable;

  TimeSlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.serviceType,
    required this.isAvailable,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'];
    final date = DateTime.parse('$dateStr 00:00:00');
    
    final startStr = json['start_time'];
    final endStr = json['end_time'];
    
    final startDt = DateTime.parse('2000-01-01T${startStr.length == 5 ? "$startStr:00" : startStr}');
    final endDt = DateTime.parse('2000-01-01T${endStr.length == 5 ? "$endStr:00" : endStr}');

    return TimeSlot(
      id: json['id'],
      date: date,
      startTime: TimeOfDay.fromDateTime(startDt),
      endTime: TimeOfDay.fromDateTime(endDt),
      serviceType: json['service_type'],
      isAvailable: json['is_available'],
    );
  }

  String get displayTime {
    final now = DateTime.now();
    final dtStart = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    final dtEnd = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
    final format = DateFormat('HH:mm');
    return '${format.format(dtStart)} - ${format.format(dtEnd)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlot && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ServiceRequest {
  final String id;
  final String profileId;
  final String vehicleId;
  final String? slotId;
  final String? suggestedSlotId;
  final String type;
  final String? description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TimeSlot? slot;
  final TimeSlot? suggestedSlot;
  final Vehicle? vehicle;

  ServiceRequest({
    required this.id,
    required this.profileId,
    required this.vehicleId,
    this.slotId,
    this.suggestedSlotId,
    required this.type,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.slot,
    this.suggestedSlot,
    this.vehicle,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'],
      profileId: json['profile_id'],
      vehicleId: json['vehicle_id'],
      slotId: json['slot_id'],
      suggestedSlotId: json['suggested_slot_id'],
      type: json['type'],
      description: json['description'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      slot: json['time_slots'] != null ? TimeSlot.fromJson(json['time_slots']) : null,
      suggestedSlot: json['suggested_time_slot'] != null ? TimeSlot.fromJson(json['suggested_time_slot']) : null,
      vehicle: json['vehicles'] != null ? Vehicle.fromJson(json['vehicles']) : null,
    );
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.green;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class CustomerBookings extends StatefulWidget {
  const CustomerBookings({super.key});

  @override
  State<CustomerBookings> createState() => _CustomerBookingsState();
}

class _CustomerBookingsState extends State<CustomerBookings> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient supabase = Supabase.instance.client;
  
  List<ServiceRequest> upcoming = [];
  List<ServiceRequest> history = [];
  List<Vehicle> vehicles = [];
  List<TimeSlot> availableSlots = [];
  
  Vehicle? selectedVehicle;
  String? selectedType;
  DateTime selectedDate = DateTime.now();
  TimeSlot? selectedSlot;
  bool isLoading = false;
  String? _editingRequestId;
  
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 2 && _editingRequestId != null) {
        setState(() {
          _editingRequestId = null;
          _clearForm();
        });
      }
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    Fluttertoast.showToast(
  msg: message,
  toastLength: Toast.LENGTH_LONG,
  gravity: ToastGravity.TOP,
  backgroundColor: ThemeColorManager.getSafeColor(),
  textColor: ThemeColorManager.getColor(),  
  fontSize: 16.0,
);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: ThemeColorManager.getSafeColor(),
      textColor: ThemeColorManager.getColor(),
      fontSize: 16.0,
    );
  }

  void _clearForm() {
    _descriptionController.clear();
    selectedSlot = null;
    availableSlots.clear();
    selectedDate = DateTime.now();
    selectedType = null;
    _editingRequestId = null;
    _fetchPrimaryVehicle(supabase.auth.currentUser?.id);
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await Future.wait([
        _fetchVehicles(userId),
        _fetchUpcoming(userId),
        _fetchHistory(userId),
      ]);
      
      await _fetchPrimaryVehicle(userId);
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchVehicles(String userId) async {
    final response = await supabase
        .from('vehicles')
        .select()
        .eq('profile_id', userId);
    
    if (mounted) {
      setState(() {
        vehicles = (response as List).map((json) => Vehicle.fromJson(json)).toList();
      });
    }
  }

  Future<void> _fetchPrimaryVehicle(String? userId) async {
    if (userId == null || vehicles.isEmpty) return;
    if (_editingRequestId != null) return; 

    try {
      final primaryResponse = await supabase
          .from('primary_vehicle')
          .select('vehicle_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (primaryResponse != null) {
            final vid = primaryResponse['vehicle_id'] as String;
            selectedVehicle = vehicles.firstWhere(
              (v) => v.id == vid, 
              orElse: () => vehicles.first
            );
          } else {
            selectedVehicle = vehicles.first;
          }
        });
      }
    } catch (e) {
      if (mounted && vehicles.isNotEmpty) {
        setState(() => selectedVehicle = vehicles.first);
      }
    }
  }

  Future<void> _fetchUpcoming(String userId) async {
    final response = await supabase
        .from('service_requests')
        .select('*, time_slots:time_slots!service_requests_slot_id_fkey(*), suggested_time_slot:time_slots!service_requests_suggested_slot_id_fkey(*), vehicles(*)')
        .eq('profile_id', userId)
        .inFilter('status', ['pending', 'confirmed'])
        .order('created_at', ascending: false);
        
    if (mounted) {
      setState(() {
        upcoming = (response as List).map((json) => ServiceRequest.fromJson(json)).toList();
      });
    }
  }

  Future<void> _fetchHistory(String userId) async {
    final response = await supabase
        .from('service_requests')
        .select('*, time_slots:time_slots!service_requests_slot_id_fkey(*), suggested_time_slot:time_slots!service_requests_suggested_slot_id_fkey(*), vehicles(*)')
        .eq('profile_id', userId)
        .inFilter('status', ['completed', 'cancelled'])
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        history = (response as List).map((json) => ServiceRequest.fromJson(json)).toList();
      });
    }
  }

  Future<void> _fetchAvailableSlots(String type, DateTime date) async {
    setState(() => isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await supabase
          .from('time_slots')
          .select()
          .eq('date', dateStr)
          .eq('service_type', type)
          .eq('is_available', true)
          .order('start_time');
      
      if (mounted) {
        setState(() {
          availableSlots = (response as List).map((json) => TimeSlot.fromJson(json)).toList();
          if (selectedSlot != null && !availableSlots.contains(selectedSlot)) {
            selectedSlot = null;
          }
        });
      }
    } catch (e) {
      _showError('Error fetching slots: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (selectedVehicle == null || selectedType == null || selectedSlot == null) {
      _showError('Please complete all fields');
      return;
    }

    setState(() => isLoading = true);
    try {
      final description = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();
      
      if (_editingRequestId != null) {
        await supabase.from('service_requests').update({
          'vehicle_id': selectedVehicle!.id,
          'slot_id': selectedSlot!.id,
          'type': selectedType,
          'description': description,
          'status': 'pending',
          'suggested_slot_id': null,
        }).eq('id', _editingRequestId!);
        _showSuccess('Booking updated successfully');
      } else {
        await supabase.from('service_requests').insert({
          'profile_id': userId,
          'vehicle_id': selectedVehicle!.id,
          'slot_id': selectedSlot!.id,
          'type': selectedType,
          'description': description,
          'status': 'pending',
        });
        _showSuccess('Booking requested successfully');
      }

      _clearForm();
      _tabController.animateTo(0);
      await _fetchUpcoming(userId);
      
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _acceptSuggested(String requestId, String suggestedSlotId) async {
    try {
      await supabase
          .from('service_requests')
          .update({
            'slot_id': suggestedSlotId, 
            'status': 'confirmed', 
            'suggested_slot_id': null
          })
          .eq('id', requestId);
      
      _showSuccess('New time slot accepted');
      await _fetchUpcoming(supabase.auth.currentUser!.id);
    } catch (e) {
      _showError('Error updating booking: $e');
    }
  }

  Future<void> _cancelRequest(ServiceRequest request) async {
    try {
      await supabase
          .from('service_requests')
          .update({'status': 'cancelled'})
          .eq('id', request.id);
      
      _showSuccess('Booking cancelled');
      await Future.wait([
        _fetchUpcoming(supabase.auth.currentUser!.id),
        _fetchHistory(supabase.auth.currentUser!.id),
      ]);
    } catch (e) {
      _showError('Error cancelling: $e');
    }
  }

  // Future<void> _amendRequest(ServiceRequest request) async {
  //   _tabController.animateTo(2);
    
  //   setState(() {
  //     _editingRequestId = request.id;
  //     if (vehicles.any((v) => v.id == request.vehicleId)) {
  //       selectedVehicle = vehicles.firstWhere((v) => v.id == request.vehicleId);
  //     }
      
  //     selectedType = request.type;
      
  //     if (request.slot != null) {
  //       selectedDate = request.slot!.date;
  //     }
      
  //     _descriptionController.text = request.description ?? '';
  //   });

  //   if (selectedType != null) {
  //     await _fetchAvailableSlots(selectedType!, selectedDate);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeColorManager.refresh,
      builder: (context, _, __) {
        final themeColor = ThemeColorManager.getColor();
        final safeColor = ThemeColorManager.getSafeColor();

        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: themeColor,
            scaffoldBackgroundColor: themeColor,
            
            appBarTheme: AppBarTheme(
              backgroundColor: themeColor,
              foregroundColor: safeColor,
              iconTheme: IconThemeData(color: safeColor),
            ),
            colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: themeColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: ThemeColorManager.getColor(),
              surfaceTintColor: ThemeColorManager.getColor(),
              elevation: 0,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
              toolbarHeight: 80.0,
              title: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'My Bookings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: safeColor,
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Column(
                  children: [
                    TabBar(
                    controller: _tabController,
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    indicatorColor: safeColor,
                    indicatorWeight: 2,
                    labelColor: safeColor,
                    unselectedLabelColor: safeColor.withAlpha(0x66),
                    labelStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 5),
                    tabs: const [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'History'),
                      Tab(text: 'Booking'),
                    ],
                  ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: safeColor,
                      height: 0.5,
                    ),
                  ],
                ),
              ),
            ),
            body: isLoading && vehicles.isEmpty 
                ?  Center(child: CircularProgressIndicator(color: safeColor))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpcomingTab(themeColor, safeColor),
                      _buildHistoryTab(themeColor, safeColor),
                      _buildBookingTab(themeColor, safeColor),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingTab(Color themeColor, Color safeColor) {
    if (upcoming.isEmpty) {
    return RefreshIndicator(
      onRefresh: () async => _loadInitialData(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 300),
          Center(child: Text('No upcoming bookings')),
        ],
      ),
    );
  }
    return RefreshIndicator(
      onRefresh: () async => _loadInitialData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: upcoming.length,
        itemBuilder: (context, index) {
          final request = upcoming[index];
          
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: safeColor.withAlpha(0x80), width: 1.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Card(
            color: themeColor,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${request.vehicle?.make ?? 'Vehicle'} ${request.vehicle?.model ?? ''}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: safeColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: request.statusColor.withAlpha(0x1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: request.statusColor),
                        ),
                        child: Text(
                          request.status.toUpperCase(),
                          style: TextStyle(color: request.statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Type: ${request.type.toUpperCase()}', style: TextStyle(color: safeColor, fontWeight: FontWeight.w500)),
                  if (request.slot != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(request.slot!.date)} at ${request.slot!.displayTime}',
                        style: TextStyle(color: safeColor.withAlpha(0xCC)),
                      ),
                    ),
                  if (request.description != null && request.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Note: ${request.description}',
                        style: TextStyle(fontStyle: FontStyle.italic, color: safeColor.withAlpha(0xCC)),
                      ),
                    ),
                  if (request.suggestedSlotId != null && request.suggestedSlot != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(0x1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin suggested new time:', style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold)),
                          Text('${DateFormat('yyyy-MM-dd').format(request.suggestedSlot!.date)} at ${request.suggestedSlot!.displayTime}'),
                          TextButton(
                            onPressed: () => _acceptSuggested(request.id, request.suggestedSlotId!),
                            child: const Text('Accept New Time'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // TextButton.icon(
                      //   icon: Icon(Icons.edit, size: 16, color: safeColor),
                      //   label: Text('Amend', style: TextStyle(color: safeColor)),
                      //   onPressed: () => _amendRequest(request),
                      // ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                        label: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 18)),
                        onPressed: () => _cancelRequest(request),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildHistoryTab(Color themeColor, Color safeColor) {
    if (history.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadInitialData(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          children:  [
            SizedBox(height: 300), 
            Center(child: Text('No booking history',style: TextStyle(color: ThemeColorManager.getSafeColor()))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _loadInitialData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final request = history[index];
          return Card(
            color: themeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: safeColor,
                width: 1,
              ),
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                '${request.vehicle?.make ?? ''} ${request.vehicle?.model ?? ''}',
                style: TextStyle(color: safeColor),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${request.type.toUpperCase()} - ${DateFormat('MMM d, y').format(request.createdAt)}',
                    style: TextStyle(color: safeColor.withValues()),
                  ),
                  if (request.slot != null) 
                    Text('Slot: ${request.slot!.displayTime}', style: TextStyle(color: safeColor.withValues())),
                ],
              ),
              trailing: Chip(
                label: Text(request.status, style:  TextStyle(color: Colors.white, fontSize: 14)),
                backgroundColor: request.statusColor,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side:  BorderSide(
                    color: themeColor,
                    width: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingTab(Color themeColor, Color safeColor) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_editingRequestId != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                width: double.infinity,
                color: Colors.amber.withAlpha(0x1A),
                child:  Text('Editing Booking', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold,color: safeColor)),
              ),

             Text('Vehicle Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: safeColor)),
            const SizedBox(height: 8),
            if (vehicles.isNotEmpty)
              DropdownButtonFormField<Vehicle>(
                dropdownColor:themeColor,
                initialValue: selectedVehicle,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(),
                ),
                isExpanded: true,
                onChanged: (vehicle) {
                  setState(() {
                    selectedVehicle = vehicle;
                  });
                },
                items: vehicles.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text('${v.make} ${v.model} - ${v.numberPlate}',style: TextStyle(color: safeColor)),
                )).toList(),
              )
            else
               Text('No vehicles found. Please add a vehicle in your profile.',style: TextStyle(color: ThemeColorManager.getSafeColor())),
              
            const SizedBox(height: 24),
             Text('Service Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: safeColor)),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<String>(
              dropdownColor:themeColor,
              initialValue: selectedType,
              decoration:  InputDecoration(
                labelText: 'Service Type',
                labelStyle: TextStyle(color: safeColor),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(),
              ),
              items: ['service', 'maintenance'].map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.toUpperCase(),style: TextStyle(color: ThemeColorManager.getSafeColor())),
              )).toList(),
              onChanged: (type) {
                setState(() {
                  selectedType = type;
                  selectedSlot = null;
                  availableSlots.clear();
                });
                if (type != null) {
                  _fetchAvailableSlots(type, selectedDate);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: safeColor,
                          onPrimary: themeColor,
                          surface: themeColor,
                          onSurface: safeColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    selectedSlot = null;
                    availableSlots.clear();
                  });
                  if (selectedType != null) {
                    _fetchAvailableSlots(selectedType!, picked);
                  }
                }
              },
              child: InputDecorator(
                decoration:  InputDecoration(
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(),
                  labelText: 'Date',
                  labelStyle: TextStyle(color: safeColor),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('EEEE, MMMM d, y').format(selectedDate),
                  style:  TextStyle(fontSize: 16,color: safeColor),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (isLoading)
              Center(child: CircularProgressIndicator(color: safeColor))
            else if (selectedType != null && availableSlots.isEmpty)
               Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No available slots for this date/type.', style: TextStyle(color: safeColor)),
                ),
              )
            else if (selectedType != null) ...[
              Text(
                'Available Time Slots (${availableSlots.length})', 
                style:  TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: safeColor)
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: availableSlots.map((slot) {
                  final isSelected = selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(slot.displayTime),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedSlot = selected ? slot : null);
                    },
                    backgroundColor: themeColor,
                    selectedColor: themeColor,
                    labelStyle: TextStyle(
                      color: isSelected ? safeColor : safeColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],

            if (selectedType == 'maintenance') ...[
              const SizedBox(height: 24),
               Text('Issue Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: safeColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration:  InputDecoration(
                  labelStyle: TextStyle(color: safeColor),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(),
                  hintText: 'Please describe the issue with your vehicle...',
                ),
                maxLines: 4,
              ),
            ],

            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading || selectedSlot == null || selectedVehicle == null
                    ? null
                    : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: safeColor,
                  foregroundColor: safeColor,
                  elevation: 2,
                ),
                child: Text(_editingRequestId != null ? 'UPDATE BOOKING' : 'CONFIRM BOOKING',style: TextStyle(color: ThemeColorManager.getColor())),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

}