// lib/admin/screens/service_slot_management_screen.dart
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
    final sel =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    return !sel.isBefore(DateTime(today.year, today.month, today.day));
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadSlots);
  }

  Future<void> _loadSlots() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final dateStr = _selectedDay!.toIso8601String().split('T').first;

      final response = await supabase
          .from('time_slots')
          .select('id, date, start_time, end_time, service_type, is_available')
          .eq('date', dateStr)
          .order('start_time')
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;
      setState(() {
        _slots = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load slots: $e')),
      );
    }
  }

  void _showSlotSheet({Map<String, dynamic>? slot}) {
    final isEdit = slot != null;

    TimeOfDay? startTime = isEdit ? _parseTime(slot['start_time']) : null;
    TimeOfDay? endTime = isEdit ? _parseTime(slot['end_time']) : null;
    String serviceType = isEdit ? slot['service_type'] : 'service';
    bool isAvailable = isEdit ? slot['is_available'] : true;
    bool saving = false;

    BuildContext? sheetCtx;
    final bool use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        sheetCtx = ctx;
        return StatefulBuilder(
          builder: (context, setStateSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? 'Edit Slot' : 'Add New Slot',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D141B),
                  ),
                ),
                const SizedBox(height: 20),

                // START TIME
                ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF0D141B)),
                  title: Text(
                    startTime == null
                        ? 'Select Start Time'
                        : use24Hour
                            ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
                            : startTime!.format(context),
                    style: TextStyle(
                      color: startTime == null ? Colors.grey[600] : const Color(0xFF0D141B),
                    ),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: startTime ?? TimeOfDay.now(),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hour),
                          child: child!,
                        );
                      },
                    );
                    if (t != null) setStateSheet(() => startTime = t);
                  },
                ),

                // END TIME
                ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF0D141B)),
                  title: Text(
                    endTime == null
                        ? 'Select End Time'
                        : use24Hour
                            ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                            : endTime!.format(context),
                    style: TextStyle(
                      color: endTime == null ? Colors.grey[600] : const Color(0xFF0D141B),
                    ),
                  ),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: endTime ?? (startTime ?? TimeOfDay.now()),
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24Hour),
                          child: child!,
                        );
                      },
                    );
                    if (t != null) setStateSheet(() => endTime = t);
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  decoration: const InputDecoration(
                    labelText: 'Service Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setStateSheet(() => serviceType = v!),
                ),

                SwitchListTile(
                  title: const Text('Available'),
                  value: isAvailable,
                  activeThumbColor: const Color(0xFF1172D4),
                  onChanged: (v) => setStateSheet(() => isAvailable = v),
                ),

                const SizedBox(height: 24),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1172D4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: startTime == null || endTime == null || saving
                        ? null
                        : () async {
                            setStateSheet(() => saving = true);
                            try {
                              final startStr =
                                  '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                              final endStr =
                                  '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                              final data = {
                                'date': _selectedDay!.toIso8601String().split('T').first,
                                'start_time': startStr,
                                'end_time': endStr,
                                'service_type': serviceType,
                                'is_available': isAvailable,
                              };

                              if (isEdit) {
                                await supabase
                                    .from('time_slots')
                                    .update(data)
                                    .eq('id', slot['id']);
                              } else {
                                await supabase.from('time_slots').insert(data);
                              }

                              if (!mounted) return;
                              if (sheetCtx != null && sheetCtx!.mounted) {
                                Navigator.of(sheetCtx!).pop();
                              }
                              _scheduleLoad();
                            } catch (e) {
                              if (!mounted) return;
                              setStateSheet(() => saving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Save failed: $e')),
                              );
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

                // DELETE BUTTON (only in edit mode)
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Slot?'),
                            content: Text(
                                'Delete ${slot['start_time']} - ${slot['end_time']} on ${_selectedDay!.toIso8601String().split('T').first}?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );

                        if (confirm != true || !mounted) return;

                        try {
                          await supabase.from('time_slots').delete().eq('id', slot['id']);
                          if (sheetCtx != null && sheetCtx!.mounted) {
                            Navigator.of(sheetCtx!).pop();
                          }
                          _scheduleLoad();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Delete failed: $e')),
                          );
                        }
                      },
                      child: const Text('Delete Slot', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D141B),
        elevation: 0,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
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
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(color: Color(0xFF1172D4), shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: Color(0xFFE0E0E0), shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            ),
          ),

          // UPDATED HERE
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Slots',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
                : _slots.isEmpty
                    ? const Center(child: Text('No slots added for this day', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _slots.length,
                        itemBuilder: (c, i) {
                          final s = _slots[i];
                          final avail = s['is_available'] as bool;
                          final service = s['service_type'] == 'service' ? 'Service' : 'Maintenance';

                          return Card(
                            color: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                            child: ListTile(
                              onLongPress: () => _showSlotSheet(slot: s),
                              title: Text(
                                'Slot ${i + 1} – $service',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('${s['start_time']} - ${s['end_time']}'),
                              trailing: Chip(
                                label: Text(avail ? 'Available' : 'Booked'),
                                backgroundColor: avail ? const Color(0xFFE7EDF3) : Colors.grey[300],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      floatingActionButton: _isTodayOrFuture
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1172D4),
              onPressed: () => _showSlotSheet(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}