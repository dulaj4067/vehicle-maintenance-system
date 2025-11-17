import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class CustomerVehicles extends StatefulWidget {
  const CustomerVehicles({super.key});

  @override
  State<CustomerVehicles> createState() => _CustomerVehiclesState();
}

class _CustomerVehiclesState extends State<CustomerVehicles> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? primaryVehicle;
  List<Map<String, dynamic>> secondaryVehicles = [];
  bool isLoading = true;

  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'white', 'color': Colors.white},
    {'name': 'black', 'color': Colors.black},
    {'name': 'gray', 'color': Colors.grey},
    {'name': 'red', 'color': Colors.red},
    {'name': 'orange', 'color': Colors.orange},
    {'name': 'yellow', 'color': Colors.yellow},
    {'name': 'green', 'color': Colors.green},
    {'name': 'blue', 'color': Colors.blue},
    {'name': 'violet', 'color': Colors.purple},
    {'name': 'brown', 'color': Colors.brown},
    {'name': 'beige', 'color': const Color(0xFFF5F5DC)},
    {'name': 'gold', 'color': const Color(0xFFFFD700)},
    {'name': 'maroon', 'color': const Color(0xFF800000)},
  ];

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    setState(() => isLoading = true);
    try {
      final profileId = supabase.auth.currentUser!.id;
      final primaryRes = await supabase
          .from('primary_vehicle')
          .select('vehicle_id')
          .eq('user_id', profileId)
          .maybeSingle();
      String? primaryId = primaryRes?['vehicle_id'] as String?;
      final allVehiclesRes = await supabase.from('vehicles').select().eq('profile_id', profileId);
      final List<Map<String, dynamic>> allVehicles = allVehiclesRes.map((e) => e).toList();
      primaryVehicle = null;
      if (primaryId != null) {
        try {
          primaryVehicle = allVehicles.firstWhere((v) => v['id'] == primaryId);
        } catch (e) {
          primaryVehicle = null;
        }
      }
      secondaryVehicles = primaryId != null
          ? allVehicles.where((v) => v['id'] != primaryId).toList()
          : allVehicles;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching vehicles: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Color _getColorObjectByName(String name) {
    return _availableColors.firstWhere(
      (c) => c['name'] == name,
      orElse: () => {'color': Colors.grey},
    )['color'] as Color;
  }

  bool _isPrimaryVehicle(Map<String, dynamic> vehicle) {
    return primaryVehicle?['id'] == vehicle['id'];
  }

  void _setAsPrimary(Map<String, dynamic> vehicle) async {
    try {
      final profileId = supabase.auth.currentUser!.id;
      await supabase
          .from('primary_vehicle')
          .delete()
          .eq('user_id', profileId);
      await supabase.from('primary_vehicle').insert({
        'user_id': profileId,
        'vehicle_id': vehicle['id'],
      });
      await _fetchVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle set as primary'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showVehicleFormDialog({
    Map<String, dynamic>? vehicle,
    bool isEdit = false,
  }) {
    final BuildContext pageContext = context;
    final profileId = supabase.auth.currentUser!.id;

    bool editing = isEdit == true; 

    String? selectedColorName = editing
        ? (vehicle != null && vehicle['color'] != null ? vehicle['color'] as String : 'black')
        : null;

    Map<String, dynamic>? documents = editing
        ? (vehicle != null && vehicle['documents'] != null ? vehicle['documents'] as Map<String, dynamic> : null)
        : null;

    String? selectedDocumentName = editing
        ? (documents != null && documents['file_name'] != null ? documents['file_name'].toString() : '')
        : '';

    String? selectedDocumentPath = editing
        ? (documents != null && documents['file_path'] != null ? documents['file_path'].toString() : '')
        : '';

    if (isEdit && vehicle != null) {
      _makeController.text = vehicle['make'] ?? '';
      _modelController.text = vehicle['model'] ?? '';
      _yearController.text = vehicle['year']?.toString() ?? '';
      _plateController.text = vehicle['number_plate'] ?? '';
    } else {
      _clearControllers();
    }

    bool isUploading = false;
    bool isSaving = false;
    String? statusMessage;
    Color? messageColor;

    showDialog(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext sbContext, StateSetter setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            isEdit
                                ? FontAwesomeIcons.penToSquare
                                : FontAwesomeIcons.plus,
                            color: Colors.black87,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEdit ? 'Edit Vehicle' : 'Add Vehicle',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_makeController, 'Make'),
                      const SizedBox(height: 16),
                      _buildTextField(_modelController, 'Model'),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _yearController,
                        'Year',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_plateController,
                          'License Plate (e.g., ABC-1234)'),
                      const SizedBox(height: 20),
                      Text(
                        'Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedColorName,
                        dropdownColor: Colors.white,
                        decoration: _buildInputDecoration(),
                        items: _availableColors.map((colorMap) {
                          return DropdownMenuItem<String>(
                            value: colorMap['name'],
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorMap['color'],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(colorMap['name']),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setDialogState(() {
                            selectedColorName = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Documents (One File)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedDocumentName == null ||
                          selectedDocumentName!.isEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isUploading ? null : () async {
                              setDialogState(() {
                                isUploading = true;
                                statusMessage = null;
                              });
                              FilePickerResult? result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf'],
                              );
                              if (result != null) {
                                final file = result.files.single;
                                if (file.bytes == null) {
                                  setDialogState(() {
                                    isUploading = false;
                                  });
                                  return;
                                }
                                final timestamp =
                                    DateTime.now().millisecondsSinceEpoch;
                                final path =
                                    'vehicles/$profileId/doc_${timestamp}_${file.name}';
                                try {
                                  await supabase.storage
                                      .from('vehicle_documents')
                                      .uploadBinary(path, file.bytes!);
                                  setDialogState(() {
                                    selectedDocumentName = file.name;
                                    selectedDocumentPath = path;
                                    isUploading = false;
                                    statusMessage = 'Document uploaded successfully.';
                                    messageColor = Colors.green;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    isUploading = false;
                                    statusMessage = 'Upload failed: $e';
                                    messageColor = Colors.red;
                                  });
                                }
                              } else {
                                setDialogState(() {
                                  isUploading = false;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isUploading)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const FaIcon(
                                    FontAwesomeIcons.upload,
                                    size: 18,
                                  ),
                                if (isUploading) const SizedBox(width: 8),
                                Text(
                                  isUploading ? 'Uploading...' : 'Upload Document',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.filePdf,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(selectedDocumentName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                              ),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedDocumentName = null;
                                    selectedDocumentPath = null;
                                  });
                                },
                                icon: const FaIcon(FontAwesomeIcons.xmark,
                                    size: 18),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      if (statusMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: messageColor!.withValues(),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: messageColor!.withValues(),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                messageColor == Colors.green
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: messageColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusMessage!,
                                  style: TextStyle(
                                    color: messageColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.grey, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: isSaving ? null : () async {
                                  setDialogState(() {
                                    isSaving = true;
                                    statusMessage = null;
                                  });
                                  final make =
                                      _makeController.text.trim();
                                  final model =
                                      _modelController.text.trim();
                                  final year =
                                      _yearController.text.trim();
                                  final plate =
                                      _plateController.text.trim();
                                  if (make.isEmpty ||
                                      model.isEmpty ||
                                      year.isEmpty ||
                                      plate.isEmpty ||
                                      selectedColorName == null) {
                                    setDialogState(() {
                                      isSaving = false;
                                      statusMessage = 'Please fill all fields';
                                      messageColor = Colors.red;
                                    });
                                    return;
                                  }
                                  final yearInt =
                                      int.tryParse(year);
                                  if (yearInt == null ||
                                      year.length != 4 ||
                                      yearInt < 1900 ||
                                      yearInt > DateTime.now().year) {
                                    setDialogState(() {
                                      isSaving = false;
                                      statusMessage = 'Invalid year';
                                      messageColor = Colors.red;
                                    });
                                    return;
                                  }
                                  final Map<String, dynamic> newData = {
                                    'make': make,
                                    'model': model,
                                    'year': yearInt,
                                    'number_plate': plate,
                                    'color': selectedColorName,
                                    'profile_id': profileId,
                                  };
                                  newData['documents'] = selectedDocumentPath != null && selectedDocumentName != null
                                      ? {
                                          'file_name': selectedDocumentName,
                                          'file_path': selectedDocumentPath,
                                        }
                                      : null;
                                  try {
                                    if (isEdit && vehicle != null) {
                                      await supabase
                                          .from('vehicles')
                                          .update(newData)
                                          .eq('id', vehicle['id']);
                                      Navigator.of(dialogContext).pop();
                                      _clearControllers();
                                      await _fetchVehicles();
                                      if (mounted) {
                                        ScaffoldMessenger.of(pageContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vehicle updated'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } else {
                                      final existingVehicles = await supabase
                                          .from('vehicles')
                                          .select()
                                          .eq('profile_id',
                                              profileId);
                                      final int count = existingVehicles.length;
                                      if (count == 0) {
                                        final inserted = await supabase
                                            .from('vehicles')
                                            .insert(newData)
                                            .select()
                                            .single();
                                        await supabase
                                            .from('primary_vehicle')
                                            .insert({
                                          'user_id': profileId,
                                          'vehicle_id':
                                              inserted['id'],
                                        });
                                      } else {
                                        await supabase
                                            .from('vehicles')
                                            .insert(newData);
                                      }
                                      Navigator.of(dialogContext).pop();
                                      _clearControllers();
                                      await _fetchVehicles();
                                      if (mounted) {
                                        ScaffoldMessenger.of(pageContext).showSnackBar(
                                          const SnackBar(
                                            content: Text('Vehicle added'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isSaving = false;
                                      statusMessage = 'Error: $e';
                                      messageColor = Colors.red;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: isSaving
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Saving...'),
                                        ],
                                      )
                                    : Text(
                                        isEdit ? 'Update' : 'Add',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.grey.shade400, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black, width: 2.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.grey.shade400, width: 2),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade400,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black,
            width: 2.5,
          ),
        ),
      ),
    );
  }

  void _clearControllers() {
    _makeController.clear();
    _modelController.clear();
    _yearController.clear();
    _plateController.clear();
  }

  void _showDeleteConfirmation(Map<String, dynamic> vehicle) {
    final BuildContext pageContext = context;
    showDialog(
      context: pageContext,
      builder: (BuildContext dialogContext) {
        bool isDeleting = false;
        String? statusMessage;
        Color? messageColor;
        return StatefulBuilder(
          builder: (BuildContext sbContext, StateSetter setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.triangleExclamation,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Vehicle',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Are you sure you want to delete ${vehicle['make']} ${vehicle['model']} (${vehicle['year']})? This action cannot be undone.',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: messageColor!.withValues(),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: messageColor!.withValues(),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              messageColor == Colors.green
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: messageColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusMessage!,
                                style: TextStyle(
                                  color: messageColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isDeleting ? null : () async {
                                setDialogState(() {
                                  isDeleting = true;
                                  statusMessage = null;
                                });
                                try {
                                  final profileId =
                                      supabase.auth.currentUser!.id;
                                  if (_isPrimaryVehicle(vehicle)) {
                                    await supabase
                                        .from('primary_vehicle')
                                        .delete()
                                        .eq('user_id', profileId);
                                  }
                                  await supabase
                                      .from('vehicles')
                                      .delete()
                                      .eq('id', vehicle['id']);
                                  await _fetchVehicles();
                                  Navigator.of(dialogContext).pop();
                                  if (mounted) {
                                    ScaffoldMessenger.of(pageContext)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Vehicle deleted successfully'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    isDeleting = false;
                                    statusMessage = 'Error: $e';
                                    messageColor = Colors.red;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isDeleting
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Deleting...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Delete',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
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
        );
      },
    );
  }

  void _showVehicleDetailsDialog(Map<String, dynamic> vehicle) {
    final isPrimary = _isPrimaryVehicle(vehicle);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final documents = vehicle['documents'] as Map<String, dynamic>?;
        final hasDocuments = documents != null &&
            documents['file_name'] != null &&
            documents['file_name'].toString().isNotEmpty;
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle['make'],
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '${vehicle['model']} • ${vehicle['year']}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(
                      'License Plate',
                      Text(vehicle['number_plate'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w500))),
                  _buildDetailRow(
                    'Color',
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getColorObjectByName(
                                vehicle['color'] ?? 'gray'),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(vehicle['color'] ?? 'gray',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (hasDocuments)
                    _buildDetailRow(
                      'Documents',
                      Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.filePdf,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 12),
                          Text(
                              documents['file_name'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    _buildDetailRow(
                        'Documents',
                        const Text('No documents uploaded',
                            style: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showVehicleFormDialog(
                            vehicle: vehicle, isEdit: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Edit Vehicle',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isPrimary) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _setAsPrimary(vehicle);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Set as Primary',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDeleteConfirmation(vehicle);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete Vehicle',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }

  Widget _buildVehicleRow(Map<String, dynamic> vehicle) {
    return GestureDetector(
      onTap: () => _showVehicleDetailsDialog(vehicle),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.grey[10],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 120,
              color: _getColorObjectByName(vehicle['color'] ?? 'gray'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vehicle['make'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle['model'],
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${vehicle['year']} • ${vehicle['number_plate']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FaIcon(
                FontAwesomeIcons.chevronRight,
                color: Colors.grey[400],
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.grey,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get primaryVehicles =>
      primaryVehicle != null ? [primaryVehicle!] : [];

  @override
  Widget build(BuildContext context) {
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
          title: const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'My Vehicles',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Divider(
                color: Colors.black,
                height: 0.5,
                thickness: 0.5,
              ),
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchVehicles,
                color: Colors.black,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.only(top: 8, bottom: 16, left: 4),
                        child: Text(
                          'Primary Vehicle',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (primaryVehicles.isNotEmpty)
                        ...primaryVehicles
                            .map((vehicle) => _buildVehicleRow(vehicle))
                      else
                        _buildEmptyState('No primary vehicle'),
                      Container(
                        height: 1,
                        color: Colors.grey.shade200,
                        margin: const EdgeInsets.symmetric(vertical: 24),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16, left: 4),
                        child: Text(
                          'Secondary Vehicles',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (secondaryVehicles.isNotEmpty)
                        ...secondaryVehicles
                            .map((vehicle) => _buildVehicleRow(vehicle))
                      else
                        _buildEmptyState('No secondary vehicles'),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () => _showVehicleFormDialog(),
                          icon: const FaIcon(
                            FontAwesomeIcons.plus,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            'Add Vehicle',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}