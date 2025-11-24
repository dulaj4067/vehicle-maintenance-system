import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme_color.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Vehicle {
  final String id;
  final String make;
  final String model;
  final int year;
  final String numberPlate;
  final String color;
  final Map<String, dynamic> documents;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.numberPlate,
    required this.color,
    required this.documents,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      numberPlate: json['number_plate'] ?? '',
      color: json['color'] ?? '',
      documents: json['documents'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'number_plate': numberPlate,
      'color': color,
      'documents': documents,
    };
  }
}

class CustomerVehicles extends StatefulWidget {
  const CustomerVehicles({super.key});

  @override
  State<CustomerVehicles> createState() => _CustomerVehiclesState();
}

class _CustomerVehiclesState extends State<CustomerVehicles> {
  final supabase = Supabase.instance.client;
  List<Vehicle> vehicles = [];
  Vehicle? primaryVehicle;
  bool isLoading = true;
  bool isOperationLoading = false;
  String? profileId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => isLoading = true);
    try {
      profileId = supabase.auth.currentUser?.id;
      if (profileId == null) {
        setState(() => isLoading = false);
        return;
      }
      final vehicleResponse = await supabase
          .from('vehicles')
          .select()
          .eq('profile_id', profileId!)
          .eq('status', 'approved');
      vehicles = (vehicleResponse as List).map((e) => Vehicle.fromJson(e)).toList();

      final primaryResponse = await supabase
          .from('primary_vehicle')
          .select('vehicle_id')
          .eq('user_id', profileId!)
          .maybeSingle();
      String? primaryId;
      if (primaryResponse != null) {
        primaryId = primaryResponse['vehicle_id'];
      }
      primaryVehicle = null;
      if (primaryId != null) {
        try {
          primaryVehicle = vehicles.firstWhere((v) => v.id == primaryId);
        } catch (_) {}
      }
      if (primaryVehicle == null && vehicles.isNotEmpty) {
        primaryVehicle = vehicles.first;
        await supabase.from('primary_vehicle').upsert({
          'user_id': profileId,
          'vehicle_id': primaryVehicle!.id,
        });
      }
      await ThemeColorManager.setColor();
    } catch (e) {}
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<String?> _uploadVehicleDocument(String profileId, PlatformFile pickedFile) async {
    Uint8List fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes!;
    } else if (pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      throw Exception('Unable to read file');
    }

    final tempDir = await getTemporaryDirectory();
    final extension = pickedFile.extension ?? 'pdf';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFileName = 'vehicle_${profileId}_$timestamp.$extension';
    final tempFile = File('${tempDir.path}/$tempFileName');
    await tempFile.writeAsBytes(fileBytes);

    final fileName = tempFileName;
    final bucketPath = 'vehicles/$profileId/$fileName';

    String contentType = 'application/octet-stream';
    switch (extension.toLowerCase()) {
      case 'pdf':
        contentType = 'application/pdf';
        break;
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
    }

    final uploadedPath = await supabase.storage
        .from('vehicle_documents')
        .upload(bucketPath, tempFile, fileOptions: FileOptions(contentType: contentType));

    await tempFile.delete();

    if (uploadedPath.isEmpty) {
      throw Exception('Upload path is empty, upload failed.');
    }

    final publicUrl = supabase.storage
        .from('vehicle_documents')
        .getPublicUrl(bucketPath);

    return publicUrl;
  }

  Future<String?> _checkPlateExists(String plate, {String? excludeId}) async {
    try {
      final response = await supabase
          .from('vehicles')
          .select('id')
          .eq('number_plate', plate.trim())
          .maybeSingle();
      if (response != null && response['id'] != excludeId) {
        return 'Number plate already exists';
      }
      return null;
    } catch (e) {
      return 'Error checking number plate';
    }
  }

  Future<void> _addOrUpdateVehicle(Vehicle? existingVehicle) async {
    final isEdit = existingVehicle != null;
    final formKey = GlobalKey<FormState>();
    final makeController = TextEditingController(text: existingVehicle?.make ?? '');
    final modelController = TextEditingController(text: existingVehicle?.model ?? '');
    final yearController = TextEditingController(text: existingVehicle?.year.toString() ?? '');
    final plateController = TextEditingController(text: existingVehicle?.numberPlate ?? '');
    String? selectedColor = existingVehicle?.color ?? 'white';
    PlatformFile? selectedFile;
    String? plateError;
    bool isSubmitting = false;
    bool hasExistingDocument = isEdit && existingVehicle.documents['doc'] != null;
    String documentDisplay = hasExistingDocument ? 'Document uploaded' : '+ Add Document';

    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColorManager.getColor(),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: makeController,
                    style: TextStyle(color: ThemeColorManager.getSafeColor()),
                    decoration: InputDecoration(
                      labelText: 'Make',
                      labelStyle: TextStyle(color: ThemeColorManager.getSafeColor()),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: modelController,
                    style: TextStyle(color: ThemeColorManager.getSafeColor()),
                    decoration: InputDecoration(
                      labelText: 'Model',
                      labelStyle: TextStyle(color: ThemeColorManager.getSafeColor()),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: yearController,
                    style: TextStyle(color: ThemeColorManager.getSafeColor()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Year',
                      labelStyle: TextStyle(color: ThemeColorManager.getSafeColor()),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                    ),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      final year = int.tryParse(v!);
                      if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                        return 'Invalid year';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: plateController,
                    style: TextStyle(color: ThemeColorManager.getSafeColor()),
                    decoration: InputDecoration(
                      labelText: 'Number plate',
                      labelStyle: TextStyle(color: ThemeColorManager.getSafeColor()),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    onChanged: (v) async {
                      final error = await _checkPlateExists(v, excludeId: isEdit ? existingVehicle.id : null);
                      if (mounted) {
                        setModalState(() {
                          plateError = error;
                        });
                      }
                    },
                  ),
                  if (plateError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        plateError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedColor,
                    dropdownColor: ThemeColorManager.getColor(),
                    decoration: InputDecoration(
                      labelText: 'Color',
                      labelStyle: TextStyle(color: ThemeColorManager.getSafeColor()),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: ThemeColorManager.getSafeColor()),
                      ),
                    ),
                    items: ['white', 'black', 'gray', 'red', 'orange', 'yellow', 'green', 'blue', 'violet', 'brown', 'beige', 'gold', 'maroon']
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _colorFromString(c),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c, style: TextStyle(color: ThemeColorManager.getSafeColor())),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      selectedColor = v;
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!hasExistingDocument)
                    TextButton(
                      style: TextButton.styleFrom(
                      side: BorderSide(color: ThemeColorManager.getSafeColor()),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'png'],
                          withData: true,
                        );
                        selectedFile = result?.files.single;
                        setModalState(() {
                          documentDisplay = selectedFile != null ? 'Document Selected: ${selectedFile!.name}' : documentDisplay;
                        });
                      },
                      child: Text(documentDisplay, style: TextStyle(color: ThemeColorManager.getSafeColor())),
                    )
                  else
                    Text(documentDisplay, style: TextStyle(fontStyle: FontStyle.italic, color: ThemeColorManager.getSafeColor())),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColorManager.getSafeColor(),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isSubmitting || plateError != null
                        ? null
                        : () async {
                            if (!hasExistingDocument && selectedFile == null && !isEdit) {
                              Fluttertoast.showToast(
                                msg: "Please select a document",
                                toastLength: Toast.LENGTH_LONG, 
                                gravity: ToastGravity.TOP,      
                                backgroundColor: ThemeColorManager.getSafeColor(),
                                textColor: ThemeColorManager.getColor(),
                                fontSize: 16.0,
                                webShowClose: true,             
                              );
                              return;
                            }
                            if (formKey.currentState!.validate() && plateError == null) {
                              setState(() => isOperationLoading = true);
                              setModalState(() => isSubmitting = true);
                              try {
                                String? docUrl;
                                if (selectedFile != null) {
                                  docUrl = await _uploadVehicleDocument(profileId!, selectedFile!);
                                } else if (isEdit) {
                                  docUrl = existingVehicle.documents['doc'];
                                }
                                final vehicleData = {
                                  'make': makeController.text,
                                  'model': modelController.text,
                                  'year': int.parse(yearController.text),
                                  'number_plate': plateController.text,
                                  'color': selectedColor,
                                  'documents': {'doc': docUrl},
                                };
                                
                                if (isEdit) {
                                  final affectsPrimary = existingVehicle.id == primaryVehicle?.id;
                                  await supabase.from('vehicles').update(vehicleData).eq('id', existingVehicle.id);
                                  final updatedVehicle = Vehicle.fromJson({
                                    ...existingVehicle.toJson(),
                                    ...vehicleData,
                                  });
                                  final index = vehicles.indexWhere((v) => v.id == existingVehicle.id);
                                  if (index != -1) {
                                    vehicles[index] = updatedVehicle;
                                  }
                                  if (affectsPrimary) {
                                    primaryVehicle = updatedVehicle;
                                    await ThemeColorManager.setColor();
                                  }
                                } else {
                                  await supabase.from('vehicles').insert({
                                    ...vehicleData,
                                    'profile_id': profileId,
                                    'status': 'pending',
                                  });
                                  if (mounted) {
                                    Fluttertoast.showToast(
                                      msg: "Vehicle submitted successfully. Waiting for approval.",
                                      toastLength: Toast.LENGTH_LONG,
                                      gravity: ToastGravity.TOP,
                                      backgroundColor: ThemeColorManager.getSafeColor(),
                                      textColor: ThemeColorManager.getColor(),
                                      fontSize: 16.0,
                                    );
                                  }
                                }
                                
                                if (mounted) {
                                  Navigator.pop(context);
                                  _loadVehicles();
                                }
                              } catch (e) {
                                if (mounted) {
                                  Fluttertoast.showToast(
                                    msg: "Error: $e",
                                    toastLength: Toast.LENGTH_LONG,
                                    gravity: ToastGravity.TOP,
                                    backgroundColor: ThemeColorManager.getSafeColor(), 
                                    textColor: ThemeColorManager.getColor(),      
                                    fontSize: 16.0,
                                  );
                                }
                              }
                              if (mounted) {
                                setState(() => isOperationLoading = false);
                                setModalState(() => isSubmitting = false);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                          )
                        : Text(isEdit ? 'Update' : 'Add', style: TextStyle(color: ThemeColorManager.getColor())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Delete ${vehicle.make} ${vehicle.model}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => isOperationLoading = true);
    try {
      await supabase.from('vehicles').delete().eq('id', vehicle.id).eq('profile_id', profileId!);
      if (vehicle.id == primaryVehicle?.id) {
        await supabase.from('primary_vehicle').delete().eq('user_id', profileId!);
        primaryVehicle = null;
        await ThemeColorManager.setColor();
      }
      _loadVehicles();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: ThemeColorManager.getSafeColor(),
        textColor: ThemeColorManager.getColor(),
        fontSize: 16.0,
      );
    }
    if (mounted) {
      setState(() => isOperationLoading = false);
    }
  }

  Future<void> _setAsPrimary(Vehicle vehicle) async {
    setState(() => isOperationLoading = true);
    try {
      await supabase.from('primary_vehicle').delete().eq('user_id', profileId!);
      await supabase.from('primary_vehicle').insert({
        'user_id': profileId,
        'vehicle_id': vehicle.id,
      });
      setState(() {
        primaryVehicle = vehicle;
      });
      await ThemeColorManager.setColor();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: ThemeColorManager.getSafeColor(),
        textColor: ThemeColorManager.getColor(),
        fontSize: 16.0,
      );
    }
    if (mounted) {
      setState(() => isOperationLoading = false);
    }
  }

  Color _colorFromString(String color) {
    return switch (color) {
      'white' => Colors.white,
      'black' => Colors.black,
      'gray' => Colors.grey,
      'red' => Colors.red,
      'orange' => Colors.orange,
      'yellow' => Colors.yellow,
      'green' => Colors.green,
      'blue' => Colors.blue,
      'violet' => Colors.purple,
      'brown' => Colors.brown,
      'beige' => Colors.brown[200]!,
      'gold' => Colors.amber,
      'maroon' => Colors.brown[700]!,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final secondaryVehicles = vehicles.where((v) => v.id != primaryVehicle?.id).toList();

    return Scaffold(
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
            'My vehicles',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: ThemeColorManager.getSafeColor(),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: ThemeColorManager.getSafeColor(),
            height: 0.5,
          ),
        ),
      ),
      backgroundColor: ThemeColorManager.getColor(),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: isLoading || isOperationLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Primary Vehicle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeColorManager.getSafeColor())),
                  const SizedBox(height: 8),
                  if (primaryVehicle == null)
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'No approved primary vehicles found.',
                        style: TextStyle(color: ThemeColorManager.getSafeColor(),fontSize:16),
                      ),
                    )
                  else
                    Card(
                      color: ThemeColorManager.getColor(),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: ThemeColorManager.getSafeColor(), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text('${primaryVehicle!.make} ${primaryVehicle!.model}', style: TextStyle(color: ThemeColorManager.getSafeColor())),
                        subtitle: Text('${primaryVehicle!.year} - ${primaryVehicle!.numberPlate} - ${primaryVehicle!.color}', style: TextStyle(color: ThemeColorManager.getSafeColor())),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: ThemeColorManager.getSafeColor()),
                              onPressed: isOperationLoading ? null : () => _addOrUpdateVehicle(primaryVehicle),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: ThemeColorManager.getSafeColor()),
                              onPressed: isOperationLoading ? null : () => _deleteVehicle(primaryVehicle!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Divider(color: ThemeColorManager.getSafeColor(), thickness: 1),
                  const SizedBox(height: 16),
                  Text('Secondary Vehicles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeColorManager.getSafeColor())),
                  const SizedBox(height: 8),
                  if (secondaryVehicles.isEmpty)
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'No approved secondary vehicles found.',
                        style: TextStyle(color: ThemeColorManager.getSafeColor(),fontSize:16),
                      ),
                    )
                  else
                    ...secondaryVehicles.map((v) => Card(
                          color: ThemeColorManager.getColor(),
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: ThemeColorManager.getSafeColor(), width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Text('${v.make} ${v.model}', style: TextStyle(color: ThemeColorManager.getSafeColor())),
                            subtitle: Text('${v.year} - ${v.numberPlate} - ${v.color}', style: TextStyle(color: ThemeColorManager.getSafeColor())),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: isOperationLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.star_border, color: ThemeColorManager.getSafeColor()),
                                  onPressed: isOperationLoading ? null : () => _setAsPrimary(v),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: ThemeColorManager.getSafeColor()),
                                  onPressed: isOperationLoading ? null : () => _addOrUpdateVehicle(v),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: ThemeColorManager.getSafeColor()),
                                  onPressed: isOperationLoading ? null : () => _deleteVehicle(v),
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isOperationLoading ? null : () => _addOrUpdateVehicle(null),
        backgroundColor: ThemeColorManager.getSafeColor(),
        foregroundColor: Colors.white,
        child: isOperationLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ThemeColorManager.getSafeColor())),
              )
            : Icon(Icons.add, color: ThemeColorManager.getColor()),
      ),
    );
  }
}