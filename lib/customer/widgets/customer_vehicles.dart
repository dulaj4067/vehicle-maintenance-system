import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final Color _scaffoldBgColor = const Color(0xFF060606);
  final Color _primaryTextColor = const Color(0xFFF5F0EB);
  final Color _accentColor = const Color(0xFFC0A068);
  final Color _cardBgColor = const Color(0xFF101010); 

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
      vehicles =
          (vehicleResponse as List).map((e) => Vehicle.fromJson(e)).toList();

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
    } catch (e) {}
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<String?> _uploadVehicleDocument(
      String profileId, PlatformFile pickedFile) async {
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
        .upload(bucketPath, tempFile,
            fileOptions: FileOptions(contentType: contentType));

    await tempFile.delete();

    if (uploadedPath.isEmpty) {
      throw Exception('Upload path is empty, upload failed.');
    }

    final publicUrl =
        supabase.storage.from('vehicle_documents').getPublicUrl(bucketPath);

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
    final makeController =
        TextEditingController(text: existingVehicle?.make ?? '');
    final modelController =
        TextEditingController(text: existingVehicle?.model ?? '');
    final yearController =
        TextEditingController(text: existingVehicle?.year.toString() ?? '');
    final plateController =
        TextEditingController(text: existingVehicle?.numberPlate ?? '');
    String? selectedColor = existingVehicle?.color ?? 'white';
    PlatformFile? selectedFile;
    String? plateError;
    bool isSubmitting = false;
    bool hasExistingDocument =
        isEdit && existingVehicle.documents['doc'] != null;
    String documentDisplay =
        hasExistingDocument ? 'Document uploaded' : '+ Add Document';

    await showModalBottomSheet(
      context: context,
      backgroundColor: _scaffoldBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: makeController,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: InputDecoration(
                        labelText: 'Make',
                        labelStyle:
                            TextStyle(color: _primaryTextColor.withAlpha(170)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: modelController,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: InputDecoration(
                        labelText: 'Model',
                        labelStyle:
                            TextStyle(color: _primaryTextColor.withAlpha(170)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: yearController,
                      style: TextStyle(color: _primaryTextColor),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Year',
                        labelStyle:
                            TextStyle(color: _primaryTextColor.withAlpha(170)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final year = int.tryParse(v!);
                        if (year == null ||
                            year < 1900 ||
                            year > DateTime.now().year + 1) {
                          return 'Invalid year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: plateController,
                      style: TextStyle(color: _primaryTextColor),
                      decoration: InputDecoration(
                        labelText: 'Number plate',
                        labelStyle:
                            TextStyle(color: _primaryTextColor.withAlpha(170)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      onChanged: (v) async {
                        final error = await _checkPlateExists(v,
                            excludeId: isEdit ? existingVehicle.id : null);
                        if (mounted) {
                          setModalState(() {
                            plateError = error;
                          });
                        }
                      },
                    ),
                    if (plateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          plateError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedColor,
                      dropdownColor: _scaffoldBgColor,
                      decoration: InputDecoration(
                        labelText: 'Color',
                        labelStyle:
                            TextStyle(color: _primaryTextColor.withAlpha(170)),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                      ),
                      items: [
                        'white',
                        'black',
                        'gray',
                        'red',
                        'orange',
                        'yellow',
                        'green',
                        'blue',
                        'violet',
                        'brown',
                        'beige',
                        'gold',
                        'maroon'
                      ]
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
                                          border:
                                              Border.all(color: Colors.grey)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c,
                                        style: TextStyle(
                                            color: _primaryTextColor)),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        selectedColor = v;
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 24),
                    if (!hasExistingDocument)
                      TextButton(
                        style: TextButton.styleFrom(
                          side: BorderSide(color: _accentColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'png'],
                            withData: true,
                          );
                          selectedFile = result?.files.single;
                          setModalState(() {
                            documentDisplay = selectedFile != null
                                ? 'Document Selected: ${selectedFile!.name}'
                                : documentDisplay;
                          });
                        },
                        child: Text(documentDisplay,
                            style: TextStyle(color: _accentColor)),
                      )
                    else
                      Text(documentDisplay,
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: _primaryTextColor)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: isSubmitting || plateError != null
                          ? null
                          : () async {
                              if (!hasExistingDocument &&
                                  selectedFile == null &&
                                  !isEdit) {
                                Fluttertoast.showToast(
                                  msg: "Please select a document",
                                  toastLength: Toast.LENGTH_LONG,
                                  gravity: ToastGravity.TOP,
                                  backgroundColor: _primaryTextColor,
                                  textColor: _scaffoldBgColor,
                                  fontSize: 16.0,
                                  webShowClose: true,
                                );
                                return;
                              }
                              if (formKey.currentState!.validate() &&
                                  plateError == null) {
                                setState(() => isOperationLoading = true);
                                setModalState(() => isSubmitting = true);
                                try {
                                  String? docUrl;
                                  if (selectedFile != null) {
                                    docUrl = await _uploadVehicleDocument(
                                        profileId!, selectedFile!);
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
                                    await supabase
                                        .from('vehicles')
                                        .update(vehicleData)
                                        .eq('id', existingVehicle.id);
                                  } else {
                                    await supabase.from('vehicles').insert({
                                      ...vehicleData,
                                      'profile_id': profileId,
                                      'status': 'pending',
                                    });
                                    if (mounted) {
                                      Fluttertoast.showToast(
                                        msg:
                                            "Vehicle submitted successfully. Waiting for approval.",
                                        toastLength: Toast.LENGTH_LONG,
                                        gravity: ToastGravity.TOP,
                                        backgroundColor: _primaryTextColor,
                                        textColor: _scaffoldBgColor,
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
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
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
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      _scaffoldBgColor)),
                            )
                          : Text(isEdit ? 'Update Vehicle' : 'Add Vehicle',
                              style: TextStyle(
                                  color: _scaffoldBgColor,
                                  fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
        backgroundColor: _scaffoldBgColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _accentColor, width: 0.5)),
        title:
            Text('Delete Vehicle', style: TextStyle(color: _primaryTextColor)),
        content: Text('Delete ${vehicle.make} ${vehicle.model}?',
            style: TextStyle(color: _primaryTextColor)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(color: _primaryTextColor.withAlpha(170)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => isOperationLoading = true);
    try {
      await supabase
          .from('vehicles')
          .delete()
          .eq('id', vehicle.id)
          .eq('profile_id', profileId!);
      if (vehicle.id == primaryVehicle?.id) {
        await supabase
            .from('primary_vehicle')
            .delete()
            .eq('user_id', profileId!);
        primaryVehicle = null;
      }
      _loadVehicles();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
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
      await supabase
          .from('primary_vehicle')
          .delete()
          .eq('user_id', profileId!);
      await supabase.from('primary_vehicle').insert({
        'user_id': profileId,
        'vehicle_id': vehicle.id,
      });
      setState(() {
        primaryVehicle = vehicle;
      });
      _loadVehicles();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
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
    final secondaryVehicles =
        vehicles.where((v) => v.id != primaryVehicle?.id).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _scaffoldBgColor,
        surfaceTintColor: _scaffoldBgColor,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        toolbarHeight: 80.0,
        title: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'My Vehicles',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: _accentColor,
            height: 1.0,
          ),
        ),
      ),
      backgroundColor: _scaffoldBgColor,
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        color: _accentColor,
        backgroundColor: _scaffoldBgColor,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: _accentColor))
            : isOperationLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Primary Vehicle',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryTextColor)),
                      const SizedBox(height: 8),
                      if (primaryVehicle == null)
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              'No approved primary vehicles found.',
                              style: TextStyle(
                                  color: _primaryTextColor.withAlpha(170),
                                  fontSize: 16),
                            ),
                          ),
                        )
                      else
                        Card(
                          elevation: 0,
                          color: _cardBgColor, 
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: _accentColor, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(
                                '${primaryVehicle!.make} ${primaryVehicle!.model}',
                                style: TextStyle(
                                    color: _primaryTextColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${primaryVehicle!.year} - ${primaryVehicle!.numberPlate} - ${primaryVehicle!.color}',
                                style: TextStyle(
                                    color: _primaryTextColor.withAlpha(170))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      color:
                                          _primaryTextColor.withAlpha(170)),
                                  onPressed: isOperationLoading
                                      ? null
                                      : () =>
                                          _addOrUpdateVehicle(primaryVehicle),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.red.shade400),
                                  onPressed: isOperationLoading
                                      ? null
                                      : () => _deleteVehicle(primaryVehicle!),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Divider(color: _accentColor.withAlpha(100), thickness: 1),
                      const SizedBox(height: 16),
                      Text('Secondary Vehicles',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryTextColor)),
                      const SizedBox(height: 8),
                      if (secondaryVehicles.isEmpty)
                        Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              'No approved secondary vehicles found.',
                              style: TextStyle(
                                  color: _primaryTextColor.withAlpha(170),
                                  fontSize: 16),
                            ),
                          ),
                        )
                      else
                        ...secondaryVehicles.map((v) => Card(
                              elevation: 0,
                              color: _cardBgColor,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: _primaryTextColor.withAlpha(100),
                                    width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                title: Text('${v.make} ${v.model}',
                                    style: TextStyle(
                                        color: _primaryTextColor,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    '${v.year} - ${v.numberPlate} - ${v.color}',
                                    style: TextStyle(
                                        color:
                                            _primaryTextColor.withAlpha(170))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: isOperationLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : Icon(Icons.star_border,
                                              color: _accentColor),
                                      onPressed: isOperationLoading
                                          ? null
                                          : () => _setAsPrimary(v),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined,
                                          color: _primaryTextColor
                                              .withAlpha(170)),
                                      onPressed: isOperationLoading
                                          ? null
                                          : () => _addOrUpdateVehicle(v),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red.shade400),
                                      onPressed: isOperationLoading
                                          ? null
                                          : () => _deleteVehicle(v),
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
        backgroundColor: _accentColor,
        foregroundColor: _scaffoldBgColor,
        child: isOperationLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_scaffoldBgColor)),
              )
            : FaIcon(FontAwesomeIcons.plus, color: _scaffoldBgColor),
      ),
    );
  }
}