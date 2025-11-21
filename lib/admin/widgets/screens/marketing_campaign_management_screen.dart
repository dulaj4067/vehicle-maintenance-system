// lib/admin/screens/marketing_campaign_management_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum LoyaltySegment { all, bronze, silver, gold }

extension LoyaltySegmentX on LoyaltySegment {
  String get value => name;
  String get displayName => switch (this) {
        LoyaltySegment.all => 'All Customers',
        LoyaltySegment.bronze => 'Bronze Members',
        LoyaltySegment.silver => 'Silver Members',
        LoyaltySegment.gold => 'Gold Members',
      };
}

class MarketingCampaignManagementScreen extends StatefulWidget {
  const MarketingCampaignManagementScreen({super.key});

  @override
  State<MarketingCampaignManagementScreen> createState() =>
      _MarketingCampaignManagementScreenState();
}

class _MarketingCampaignManagementScreenState
    extends State<MarketingCampaignManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> campaigns = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('campaigns')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          campaigns = List<Map<String, dynamic>>.from(response);
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading campaigns: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showCampaignSheet({Map<String, dynamic>? campaign}) async {
    final isEdit = campaign != null;
    final titleController = TextEditingController(text: campaign?['title'] ?? '');
    final contentController = TextEditingController(text: campaign?['content'] ?? '');

    final segmentValue = campaign?['segment'] as String? ?? 'all';
    LoyaltySegment selectedSegment = LoyaltySegment.values.firstWhere(
      (e) => e.value == segmentValue,
      orElse: () => LoyaltySegment.all,
    );

    DateTime startDate = campaign?['start_date'] != null
        ? DateTime.parse(campaign!['start_date'] as String)
        : DateTime.now();
    DateTime endDate = campaign?['end_date'] != null
        ? DateTime.parse(campaign!['end_date'] as String)
        : DateTime.now().add(const Duration(days: 7));

    bool isActive = campaign?['is_active'] as bool? ?? true;
    String? imageUrl = campaign?['image_url'] as String?;
    File? selectedImage;

    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StatefulBuilder(
            builder: (context, setStateSheet) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                const _DragHandle(),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'Edit Campaign' : 'New Campaign',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null && mounted) {
                      setStateSheet(() => selectedImage = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1172D4).withAlpha(77), width: 2),
                    ),
                    child: selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(selectedImage!, fit: BoxFit.cover),
                          )
                        : imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(imageUrl, fit: BoxFit.cover),
                              )
                            : const _ImagePlaceholder(),
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Campaign Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Campaign Message',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<LoyaltySegment>(
                  value: selectedSegment,
                  decoration: InputDecoration(
                    labelText: 'Target Audience',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  items: LoyaltySegment.values
                      .map((seg) => DropdownMenuItem(
                            value: seg,
                            child: Text(seg.displayName),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setStateSheet(() => selectedSegment = v);
                  },
                ),
                const SizedBox(height: 16),

                _DateTile(
                  label: 'Start Date',
                  date: startDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setStateSheet(() => startDate = date);
                  },
                ),
                _DateTile(
                  label: 'End Date',
                  date: endDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setStateSheet(() => endDate = date);
                  },
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Campaign Active'),
                  value: isActive,
                  activeThumbColor: const Color(0xFF1172D4),
                  onChanged: (v) => setStateSheet(() => isActive = v),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1172D4),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Title and message are required'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    setStateSheet(() {});

                    String? uploadedImageUrl = imageUrl;

                    try {
                      if (selectedImage != null) {
                        final fileName = 'marketing_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final bytes = await selectedImage!.readAsBytes();

                        await supabase.storage
                            .from('marketing_images')
                            .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: false));

                        uploadedImageUrl = supabase.storage.from('marketing_images').getPublicUrl(fileName);
                      }

                      final data = {
                        'title': titleController.text.trim(),
                        'content': contentController.text.trim(),
                        'image_url': uploadedImageUrl,
                        'segment': selectedSegment.value,
                        'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                        'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                        'is_active': isActive,
                        'created_by': supabase.auth.currentUser!.id,
                      };

                      if (isEdit) {
                        await supabase.from('campaigns').update(data).eq('id', campaign['id']);
                      } else {
                        await supabase.from('campaigns').insert(data);
                      }

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Campaign ${isEdit ? 'updated' : 'created'} successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      Navigator.pop(context);
                      _loadCampaigns();
                    } catch (e) {
                      debugPrint('Campaign Error: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: Text(
                    isEdit ? 'Update Campaign' : 'Create Campaign',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

                if (isEdit) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Campaign?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (confirm != true || !mounted) return;

                      try {
                        await supabase.from('campaigns').delete().eq('id', campaign['id']);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Campaign deleted'), backgroundColor: Colors.green),
                        );
                        Navigator.pop(context);
                        _loadCampaigns();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Delete Campaign'),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // APPBAR REMOVED
      body: SafeArea(  // Added SafeArea to avoid status bar overlap
        child: loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1172D4)))
            : campaigns.isEmpty
                ? const Center(child: Text('No campaigns yet', style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: campaigns.length,
                    itemBuilder: (_, i) {
                      final c = campaigns[i];
                      final segment = c['segment'] ?? 'all';

                      final startFormatted = DateFormat('d MMM').format(DateTime.parse(c['start_date']));
                      final endFormatted = DateFormat('d MMM').format(DateTime.parse(c['end_date']));
                      final dateRange = '$startFormatted – $endFormatted';

                      return Card(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: c['image_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(c['image_url'], width: 80, height: 80, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F7FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.campaign, size: 40, color: Color(0xFF1172D4)),
                                ),
                          title: Text(
                            c['title'],
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['content'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _segmentDisplay(segment),
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          dateRange,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    c['is_active'] == true ? Icons.check_circle : Icons.pause_circle,
                                    color: c['is_active'] == true ? Colors.green : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    c['is_active'] == true ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: c['is_active'] == true ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF1172D4)),
                            onPressed: () => _showCampaignSheet(campaign: c),
                          ),
                          onTap: () => _showCampaignSheet(campaign: c),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1172D4),
        onPressed: _showCampaignSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Campaign',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  String _segmentDisplay(String segment) => {
        'bronze': 'Bronze Members',
        'silver': 'Silver Members',
        'gold': 'Gold Members',
        'all': 'All Customers',
      }[segment] ?? 'All Customers';
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 60,
          height: 6,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
        ),
      );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 60, color: const Color(0xFF1172D4).withAlpha(153)),
          const SizedBox(height: 12),
          const Text('Tap to add image', style: TextStyle(color: Color(0xFF1172D4), fontSize: 16)),
        ],
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.calendar_today, color: Color(0xFF1172D4)),
        title: Text('$label: ${DateFormat('dd MMM yyyy').format(date)}'),
        onTap: onTap,
      );
}