import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class ServiceSlotManagementScreen extends StatefulWidget {
  const ServiceSlotManagementScreen({super.key});

  @override
  State<ServiceSlotManagementScreen> createState() =>
      _ServiceSlotManagementScreenState();
}

class _ServiceSlotManagementScreenState
    extends State<ServiceSlotManagementScreen> {
  final supabase = Supabase.instance.client;

  late final DateTime _firstDay;
  late final DateTime _lastDay;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _slots = [];
  bool _loading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDay = DateTime(now.year, now.month - 3, now.day);
    _lastDay = now.add(const Duration(days: 90));
    _selectedDay = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool get _isTodayOrFuture {
    if (_selectedDay == null) return false;
    final today = DateTime.now();
    final sel = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return !sel.isBefore(DateTime(today.year, today.month, today.day));
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadSlots);
  }

  Future<void> _loadSlots() async {
    if (!mounted || _selectedDay == null) return;
    setState(() => _loading = true);

    try {
      final dateStr = _selectedDay!.toIso8601String().split('T').first;

      final response = await supabase
          .from('time_slots')
          .select('id, date, start_time, end_time, service_type, is_available')
          .eq('date', dateStr)
          .order('start_time');

      if (!mounted) return;
      setState(() {
        _slots = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('Failed to load slots: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      }
    });
  }

  String _formatTo12Hour(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    return '$hour:$minute $period';
  }

  String _formatSlotTime(String start, String end) {
    return '${_formatTo12Hour(start)} - ${_formatTo12Hour(end)}';
  }

  void _showSlotSheet({Map<String, dynamic>? slot}) {
    final isEdit = slot != null;

    TimeOfDay? startTime = isEdit ? _parseTime(slot['start_time']) : null;
    TimeOfDay? endTime = isEdit ? _parseTime(slot['end_time']) : null;
    String serviceType = isEdit ? slot['service_type'] : 'service';
    bool isAvailable = isEdit ? slot['is_available'] : true;
    bool saving = false;

    BuildContext? sheetContext;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        sheetContext = ctx;
        return StatefulBuilder(
          builder: (context, setStateSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Time Slot' : 'Add New Time Slot',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Start Time Picker
                _buildTimeTile(
                  title: 'Start Time',
                  time: startTime,
                  onTap: () async {
                    final pickerContext = context;
                    if (!mounted) return;
                    final t = await showTimePicker(
                      context: pickerContext,
                      initialTime: startTime ?? TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1172D4),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black87,
                            ),
                            timePickerTheme: TimePickerThemeData(
                              backgroundColor: Colors.white,
                              hourMinuteShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF1172D4);
                                }
                                return const Color(0xFFE3F2FD);
                              }),
                              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xFF1172D4);
                              }),
                              dialHandColor: const Color(0xFF1172D4),
                              dialBackgroundColor: const Color(0xFFE3F2FD),
                              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xFF1172D4);
                              }),
                              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF1172D4);
                                }
                                return const Color(0xFFE3F2FD);
                              }),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1172D4)),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (t != null) setStateSheet(() => startTime = t);
                  },
                ),

                const SizedBox(height: 16),

                // End Time Picker
                _buildTimeTile(
                  title: 'End Time',
                  time: endTime,
                  onTap: () async {
                    final pickerContext = context;
                    if (!mounted) return;
                    final t = await showTimePicker(
                      context: pickerContext,
                      initialTime: endTime ?? (startTime ?? TimeOfDay.now()),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1172D4),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black87,
                            ),
                            timePickerTheme: TimePickerThemeData(
                              backgroundColor: Colors.white,
                              hourMinuteShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF1172D4);
                                }
                                return const Color(0xFFE3F2FD);
                              }),
                              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xFF1172D4);
                              }),
                              dialHandColor: const Color(0xFF1172D4),
                              dialBackgroundColor: const Color(0xFFE3F2FD),
                              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return const Color(0xFF1172D4);
                              }),
                              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF1172D4);
                                }
                                return const Color(0xFFE3F2FD);
                              }),
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1172D4)),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (t != null) setStateSheet(() => endTime = t);
                  },
                ),

                const SizedBox(height: 20),

                // Service Type Dropdown - White background, black text
                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Type',
                    labelStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Color(0xFF1172D4), width: 2),
                    ),
                  ),
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setStateSheet(() => serviceType = v!),
                ),

                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Available for Booking'),
                  value: isAvailable,
                  activeTrackColor: const Color(0xFF1172D4),
                  activeThumbColor: Colors.white,
                  onChanged: _isTodayOrFuture
                      ? (v) => setStateSheet(() => isAvailable = v)
                      : null,
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1172D4),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: startTime == null || endTime == null || saving
                        ? null
                        : () async {
                            setStateSheet(() => saving = true);
                            try {
                              final data = {
                                'date': _selectedDay!.toIso8601String().split('T').first,
                                'start_time':
                                    '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                                'end_time':
                                    '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                                'service_type': serviceType,
                                'is_available': isAvailable,
                              };

                              if (isEdit) {
                                await supabase.from('time_slots').update(data).eq('id', slot['id']);
                              } else {
                                await supabase.from('time_slots').insert(data);
                              }

                              if (sheetContext?.mounted ?? false) {
                                Navigator.of(sheetContext!).pop();
                              }
                              if (mounted) _scheduleLoad();
                            } catch (e) {
                              setStateSheet(() => saving = false);
                              _showSnackBar('Save failed: $e', Colors.red);
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Update Slot' : 'Add Slot',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                if (isEdit) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: const Text('Delete Slot?'),
                            content: Text('Delete ${_formatSlotTime(slot['start_time'], slot['end_time'])}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF1172D4))),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;
                        if (!mounted) return;

                        try {
                          await supabase.from('time_slots').delete().eq('id', slot['id']);
                          if (sheetContext?.mounted ?? false) {
                            Navigator.of(sheetContext!).pop();
                          }
                          if (mounted) _scheduleLoad();
                        } catch (e) {
                          _showSnackBar('Delete failed: $e', Colors.red);
                        }
                      },
                      child: const Text('Delete Slot'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeTile({
    required String title,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.access_time, color: Color(0xFF1172D4)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          time == null
              ? 'Not set'
              : _formatTo12Hour('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
          style: TextStyle(
            color: time == null ? Colors.grey[600] : const Color(0xFF1172D4),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  TimeOfDay _parseTime(String time24) {
    final parts = time24.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: _firstDay,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _scheduleLoad();
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(color: Color(0xFF1172D4), shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                  todayTextStyle: const TextStyle(color: Color(0xFF1172D4), fontWeight: FontWeight.bold),
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Time Slots • ${_slots.length} slot${_slots.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
                  : _slots.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isTodayOrFuture ? 'No slots available' : 'No slots on this date',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              if (_isTodayOrFuture) ...[
                                const SizedBox(height: 8),
                                Text('Tap + to add slots', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _slots.length,
                          itemBuilder: (c, i) {
                            final s = _slots[i];
                            final isAvailable = s['is_available'] as bool;
                            final service = s['service_type'] == 'service' ? 'Service' : 'Maintenance';

                            final statusText = _isTodayOrFuture
                                ? (isAvailable ? 'Available' : 'Booked')
                                : (isAvailable ? 'Past Available' : 'Past Booked');

                            final chipColor = _isTodayOrFuture
                                ? (isAvailable ? const Color(0xFFE3F2FD) : Colors.grey[300]!)
                                : (isAvailable ? Colors.grey[300]! : Colors.grey[500]!);

                            final textColor = _isTodayOrFuture
                                ? (isAvailable ? const Color(0xFF1172D4) : Colors.black54)
                                : (isAvailable ? Colors.grey[700]! : Colors.white);

                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onLongPress: _isTodayOrFuture ? () => _showSlotSheet(slot: s) : null,
                                title: Text('$service Slot', style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(_formatSlotTime(s['start_time'], s['end_time']), style: const TextStyle(fontSize: 16)),
                                trailing: Chip(
                                  backgroundColor: chipColor,
                                  label: Text(statusText, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),

      floatingActionButton: _isTodayOrFuture
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1172D4),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Slot'),
              onPressed: () => _showSlotSheet(),
            )
          : null,
    );
  }
}