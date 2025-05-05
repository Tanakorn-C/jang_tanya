import 'package:flutter/material.dart';
import 'dart:io'; // For File
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:medicineproject/main.dart'; // Access Medicine model
import 'package:intl/intl.dart';

class EditMedicinePage extends StatefulWidget {
  final Medicine initialMedicine; // Data of the medicine to edit

  const EditMedicinePage({super.key, required this.initialMedicine});

  @override
  State<EditMedicinePage> createState() => _EditMedicinePageState();
}

class _EditMedicinePageState extends State<EditMedicinePage> {
  // State variables
  File? _newSelectedImageFile; // Holds NEWLY picked image file
  String? _initialImageUrl; // Holds the URL passed in initially
  String? _selectedUnit;
  final Set<String> _selectedMealTimes = {};

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _StartDateController;
  late TextEditingController _EndDateController;
  late TextEditingController _morningTimeController;
  late TextEditingController _noonTimeController;
  late TextEditingController _eveningTimeController;
  late TextEditingController _beforebedTimeController;

  bool _isSaving = false; // Loading state for saving

  final List<String> _unitOptions = [
    "เม็ด",
    "ช้อนชา",
    "ช้อนโต๊ะ",
    "มิลลิลิตร",
    "กรัม",
    "ซีซี",
  ];
  final List<String> _mealTimeOptions = [
    "ก่อนอาหาร",
    "หลังอาหาร",
    "เช้า",
    "กลางวัน",
    "เย็น",
    "ก่อนนอน",
  ];

  @override
  void initState() {
    super.initState();

    // --- Initialize controllers and state with existing data ---
    _nameController = TextEditingController(text: widget.initialMedicine.name);
    _descriptionController = TextEditingController(
      text: widget.initialMedicine.description,
    );
    _quantityController = TextEditingController(
      text: widget.initialMedicine.quantity,
    );
    // Ensure the unit from the medicine is in the options list, otherwise handle default
    if (_unitOptions.contains(widget.initialMedicine.unit)) {
      _selectedUnit = widget.initialMedicine.unit;
    } else {
      _selectedUnit = null; // Or set a default like _unitOptions[0]
    }
    _initialImageUrl = widget.initialMedicine.imageUrl;

    // --- Initialize Dates (Check for nulls just in case) ---
    _StartDateController = TextEditingController(
      text: widget.initialMedicine.startDate ?? '',
    );
    _EndDateController = TextEditingController(
      text: widget.initialMedicine.endDate ?? '',
    );

    // --- Initialize Meal Times Set ---
    if (widget.initialMedicine.mealTimes.isNotEmpty) {
      _selectedMealTimes.addAll(
        widget.initialMedicine.mealTimes
            .split(',')
            .map((e) => e.trim())
            .where((e) => _mealTimeOptions.contains(e)),
      );
    }

    // --- Initialize Time Pickers ---
    _morningTimeController = TextEditingController();
    _noonTimeController = TextEditingController();
    _eveningTimeController = TextEditingController();
    _beforebedTimeController = TextEditingController();

    if (widget.initialMedicine.times.isNotEmpty) {
      final timeEntries = widget.initialMedicine.times.split(',');
      final timeFormat = DateFormat("h:mm a", "en_US"); // Use consistent format

      for (String entry in timeEntries) {
        final parts = entry.trim().split(' at ');
        if (parts.length == 2) {
          String key = parts[0].trim();
          String timeStr = parts[1].trim();
          // Assign the raw string directly as it was saved
          if (key == 'morning') _morningTimeController.text = timeStr;
          if (key == 'noon') _noonTimeController.text = timeStr;
          if (key == 'evening') _eveningTimeController.text = timeStr;
          if (key == 'beforeBed') _beforebedTimeController.text = timeStr;
        }
      }
    }
    // --- End Initialization ---
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _StartDateController.dispose();
    _EndDateController.dispose();
    _morningTimeController.dispose();
    _noonTimeController.dispose();
    _eveningTimeController.dispose();
    _beforebedTimeController.dispose();
    super.dispose();
  }

  // --- Copy Image Picking Logic ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (pickedFile != null) {
        setState(() {
          _newSelectedImageFile = File(
            pickedFile.path,
          ); // Store the NEW file locally
          // Don't clear _initialImageUrl here, build method will prioritize _newSelectedImageFile
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาดในการเลือกรูป: $e")),
        );
    }
  }

  // --- Copy Date/Time Picking Logic ---
  Future<void> _selectStartDate() async {
    DateTime initial =
        DateTime.tryParse(_StartDateController.text) ?? DateTime.now();
    DateTime? p = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (p != null)
      setState(
        () => _StartDateController.text = DateFormat('yyyy-MM-dd').format(p),
      );
  }

  Future<void> _selectEndDate() async {
    DateTime initial =
        DateTime.tryParse(_EndDateController.text) ?? DateTime.now();
    DateTime? p = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('th', 'TH'),
    );
    if (p != null)
      setState(
        () => _EndDateController.text = DateFormat('yyyy-MM-dd').format(p),
      );
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController c,
  ) async {
    TimeOfDay initial = TimeOfDay.now();
    try {
      if (c.text.isNotEmpty) {
        final parsedTime = DateFormat("h:mm a", "en_US").parse(c.text);
        initial = TimeOfDay.fromDateTime(parsedTime);
      }
    } catch (_) {}
    TimeOfDay? p = await showTimePicker(context: context, initialTime: initial);
    if (p != null) setState(() => c.text = p.format(context));
  }

  // --- Function to UPDATE data ---
  Future<void> _updateMedicine() async {
    if (_isSaving) return;

    // --- Gather data from controllers ---
    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    final int quantity = int.tryParse(_quantityController.text) ?? 0;
    final String unit = _selectedUnit ?? "";
    final String startDate = _StartDateController.text.trim();
    final String endDate = _EndDateController.text.trim();
    List<String> currentSelectedMealTimes = _selectedMealTimes.toList();
    Map<String, String> currentSelectedTimes = {
      "morning": _morningTimeController.text,
      "noon": _noonTimeController.text,
      "evening": _eveningTimeController.text,
      "beforeBed": _beforebedTimeController.text,
    };
    String timesString = currentSelectedTimes.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => "${e.key} at ${e.value}")
        .join(", ");

    // --- Basic Validation ---
    if (name.isEmpty ||
        description.isEmpty ||
        startDate.isEmpty ||
        endDate.isEmpty ||
        currentSelectedMealTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบถ้วน")),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // --- Create Data Payload for PUT request ---
    Map<String, dynamic> updatedData = {
      'name': name,
      'description': description,
      'quantity': quantity, // Send as number
      'unit': unit,
      'startDate': startDate, // Send as yyyy-MM-dd string
      'endDate': endDate, // Send as yyyy-MM-dd string
      'mealTimes': currentSelectedMealTimes.join(","),
      'times': timesString,
      // Send the original image URL back if no new image was selected
      // The backend PUT /medicines/{id} currently expects this
      'imageUrl':
          _newSelectedImageFile == null
              ? (_initialImageUrl ?? "")
              : widget.initialMedicine.imageUrl,
      // ID is in the URL, not usually in the PUT body
      // Also not sending the 'image' (Binary) field here
    };

    // --- Send PUT request ---
    final url = Uri.parse(
      'http://10.0.2.2:8080/medicines/${widget.initialMedicine.id}',
    ); // Use ID from initial data
    print('Attempting PUT request to: $url');
    print('Sending data: ${jsonEncode(updatedData)}');

    bool updateSuccess = false;
    try {
      final response = await http
          .put(
            url,
            headers: {"Content-Type": "application/json; charset=UTF-8"},
            body: jsonEncode(updatedData),
          )
          .timeout(const Duration(seconds: 15));

      print('Update Response Status Code: ${response.statusCode}');
      print('Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // 200 OK is standard for successful PUT
        updateSuccess = true;
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'แก้ไขข้อมูลไม่สำเร็จ: ${response.statusCode} ${response.body}',
              ),
            ),
          );
      }
    } catch (e) {
      print('Error updating medicine text data: $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }

    // --- Handle NEW Image Upload (Separate Request if text update succeeded) ---
    if (updateSuccess && _newSelectedImageFile != null) {
      print("Attempting to upload new image separately...");
      bool imageUploadSuccess = await _uploadNewImage(_newSelectedImageFile!);
      if (!imageUploadSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'บันทึกข้อมูลสำเร็จ แต่ไม่สามารถอัปโหลดรูปภาพใหม่ได้',
            ),
          ),
        );
      } else if (imageUploadSuccess) {
        print("New image uploaded successfully.");
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      if (updateSuccess) {
        // Pop screen and return true ONLY if the main data update was successful
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกการแก้ไขสำเร็จ')));
        Navigator.pop(context, true); // Return true on success
      }
    }
  }

  // --- Helper to Upload NEW Image (Separate Request) ---
  Future<bool> _uploadNewImage(File imageFile) async {
    final imageUploadUrl = Uri.parse(
      'http://10.0.2.2:8080/medicines/${widget.initialMedicine.id}/image',
    ); // Use PUT endpoint for image
    print("Uploading new image to $imageUploadUrl");
    try {
      var request = http.MultipartRequest('PUT', imageUploadUrl);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      ); // Add filename
      var response = await request.send().timeout(
        const Duration(seconds: 30),
      ); // Longer timeout for upload

      print("Image Upload Status Code: ${response.statusCode}");
      final respStr = await response.stream.bytesToString();
      print("Image Upload Response: $respStr");

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error uploading new image: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e')),
        );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("แก้ไขข้อมูลยา")),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Image Section (Modified) ---
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            // Use DecorationImage for easier handling
                            fit: BoxFit.cover,
                            image:
                                _newSelectedImageFile != null
                                    ? FileImage(
                                      _newSelectedImageFile!,
                                    ) // Show newly selected local file
                                    : (_initialImageUrl != null &&
                                        _initialImageUrl!.isNotEmpty)
                                    ? NetworkImage(
                                      'http://10.0.2.2:8080/medicines/${widget.initialMedicine.id}/image',
                                    ) // Show initial network image
                                    : const AssetImage(
                                          'assets/images/picIcon.png',
                                        )
                                        as ImageProvider, // Fallback AssetImage (Ensure you have this asset)
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Material(
                            color: Colors.black54,
                            type: MaterialType.circle,
                            child: InkWell(
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ), // Or offer choice child: const Padding( padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.white, size: 18,) ) ) ) )
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- Rest of the form copied from InputMed ---
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "ชื่อยา",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "รายละเอียด",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: "จำนวน",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedUnit,
                      hint: const Text("เลือกหน่วย"),
                      items:
                          _unitOptions
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged:
                          (value) => setState(() => _selectedUnit = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _StartDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "วันที่เริ่ม",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _selectStartDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _EndDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "วันที่สิ้นสุด",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _selectEndDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "ช่วงเวลาการกิน",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 2.5,
                  children:
                      _mealTimeOptions
                          .map((time) => _buildSelectableButton(time))
                          .toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  "เวลาที่ระบุ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3.5,
                  children: [
                    _buildTimePickerField("เช้า", _morningTimeController),
                    _buildTimePickerField("กลางวัน", _noonTimeController),
                    _buildTimePickerField("เย็น", _eveningTimeController),
                    _buildTimePickerField("ก่อนนอน", _beforebedTimeController),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isSaving
                                ? null
                                : _updateMedicine, // Call update function
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                                : const Text(
                                  "บันทึกการแก้ไข",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Optional Saving Overlay
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // Helper Widgets copied from InputmedState
  Widget _buildSelectableButton(String text) {
    bool isSelected = _selectedMealTimes.contains(text);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedMealTimes.remove(text);
          } else {
            _selectedMealTimes.add(text);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[300] : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.green[800] : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.check, color: Colors.green, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time),
        border: const OutlineInputBorder(),
      ),
      onTap: () => _selectTime(context, c),
    );
  }
}
