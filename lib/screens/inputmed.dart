import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medicineproject/main.dart';
import 'package:medicineproject/screens/profile.dart';
import 'package:medicineproject/screens/reminderView.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class Inputmed extends StatefulWidget {
  const Inputmed({super.key});
  @override
  State<Inputmed> createState() => _InputmedState();
}

class _InputmedState extends State<Inputmed> {
  File? _selectedImage; // Holds the currently displayed image file
  String? _selectedOption; // Unit Dropdown selection
  final Set<String> _selectedTimes = {}; // Meal times selection

  // Controllers
  final TextEditingController _StartDateController = TextEditingController();
  final TextEditingController _EndDateController = TextEditingController();
  final TextEditingController _morningTimeController = TextEditingController();
  final TextEditingController _noonTimeController = TextEditingController();
  final TextEditingController _eveningTimeController = TextEditingController();
  final TextEditingController _beforebedTimeController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // --- ADDED State Flags ---
  bool _isProcessingOCR = false;
  bool _isSubmitting = false;
  // --- END State Flags ---

  final List<String> _unitOptions = const [
    "เม็ด",
    "แคปซูล",
    "ช้อนชา",
    "ช้อนโต๊ะ",
    "มิลลิลิตร",
    "กรัม",
    "ซีซี",
  ];
  final List<String> _mealTimeOptions = const [
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
  }

  @override
  void dispose() {
    _StartDateController.dispose();
    _EndDateController.dispose();
    _morningTimeController.dispose();
    _noonTimeController.dispose();
    _eveningTimeController.dispose();
    _beforebedTimeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // --- Simple Image Picker (Doesn't trigger OCR) ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessingOCR || _isSubmitting) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          // Clear OCR fields if user manually picks a different image after scanning? Optional.
          // _nameController.clear();
          // _descriptionController.clear();
          // _quantityController.clear();
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูป: $e')),
        );
    }
  }
  // --- END Simple Image Picker ---

  // --- Date/Time Pickers
  Future<void> _selectStartDate() async {
    if (_isProcessingOCR || _isSubmitting) return;
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
    if (_isProcessingOCR || _isSubmitting) return;
    DateTime initial =
        DateTime.tryParse(_EndDateController.text) ?? DateTime.now();
    DateTime firstSelectableDate =
        DateTime.tryParse(_StartDateController.text) ?? DateTime(2000);
    DateTime? p = await showDatePicker(
      context: context,
      initialDate:
          initial.isBefore(firstSelectableDate) ? firstSelectableDate : initial,
      firstDate: firstSelectableDate,
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
    if (_isProcessingOCR || _isSubmitting) return;
    TimeOfDay initial = TimeOfDay.now();
    try {
      if (c.text.isNotEmpty) {
        final parsedDateTime = DateFormat.jm("en_US").parse(c.text);
        initial = TimeOfDay.fromDateTime(parsedDateTime);
      }
    } catch (_) {
      print("Could not parse time: ${c.text}");
    }
    TimeOfDay? p = await showTimePicker(context: context, initialTime: initial);
    if (p != null) setState(() => c.text = p.format(context));
  } // Note: format(context) uses locale but might not match DateFormat.jm

  // --- Submit Data  ---
  Future<void> _submitData() async {
    if (_isProcessingOCR || _isSubmitting) return;
    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    final String quantityStr = _quantityController.text.trim();
    final String? unit = _selectedOption;
    final String startDate = _StartDateController.text.trim();
    final String endDate = _EndDateController.text.trim();
    List<String> selectedMealTimes = _selectedTimes.toList();
    Map<String, String> selectedTimes = {
      "morning": _morningTimeController.text,
      "noon": _noonTimeController.text,
      "evening": _eveningTimeController.text,
      "beforeBed": _beforebedTimeController.text,
    };
    String timesString = selectedTimes.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => "${e.key} at ${e.value}")
        .join(", ");
    if (name.isEmpty ||
        description.isEmpty ||
        quantityStr.isEmpty ||
        unit == null ||
        startDate.isEmpty ||
        endDate.isEmpty ||
        selectedMealTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "กรุณากรอกข้อมูลยาให้ครบถ้วน (ชื่อ, รายละเอียด, จำนวน, หน่วย, วันที่, ช่วงเวลา)",
          ),
        ),
      );
      return;
    }
    final int? quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("จำนวนยาต้องเป็นตัวเลขเท่านั้น")),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final Uri url = Uri.parse('http://10.0.2.2:8080/medicines/upload');
      var request = http.MultipartRequest('POST', url);
      Map<String, dynamic> medicineData = {
        'name': name,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'startDate': startDate,
        'endDate': endDate,
        'mealTimes': selectedMealTimes.join(","),
        'times': timesString,
      };
      request.fields['medicine'] = jsonEncode(medicineData);
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedImage!.path,
            filename: _selectedImage!.path.split('/').last,
          ),
        );
      }
      var response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Submit Response: $responseBody");
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text("สำเร็จ"),
                  content: const Text("บันทึกข้อมูลสำเร็จ"),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text("ตกลง"),
                    ),
                  ],
                ),
          );
        }
      } else {
        print("Submit Error Response: $responseBody");
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text("ผิดพลาด"),
                  content: Text(
                    "ไม่สามารถบันทึกข้อมูลได้: ${response.statusCode}\n$responseBody",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("ตกลง"),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      print("Submit Exception: $e");
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("ข้อผิดพลาด"),
                content: Text("เกิดข้อผิดพลาด: $e"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("ตกลง"),
                  ),
                ],
              ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // *** -------------------------------- ***
  // *** --- OCR Related Functions --- ***
  // *** -------------------------------- ***

  // --- ADDED: Main function to trigger OCR process ---
  Future<void> _scanAndPopulateFields(ImageSource source) async {
    if (_isProcessingOCR || _isSubmitting) return; // Prevent multiple actions

    File? imageFile; // Use local variable

    // 1. Pick Image
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85, // Higher quality might help OCR
      );
      if (pickedFile == null) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected for scan.')),
          );
        return; // Exit if no image picked
      }
      imageFile = File(pickedFile.path);
      // Update UI to show picked image and loading state *before* OCR
      setState(() {
        _selectedImage = imageFile;
        _isProcessingOCR = true;
        // Clear previous results before new scan
        _nameController.clear();
        _descriptionController.clear();
        _quantityController.clear();
      });
    } catch (e) {
      print("Error picking image for OCR: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเลือกรูป: $e')),
        );
      setState(() {
        _isProcessingOCR = false;
      }); // Reset loading state
      return;
    }

    // 2. Perform OCR
    RecognizedText? recognizedText;
    if (imageFile != null) {
      recognizedText = await _performOCR(imageFile);
    }

    // 3. Parse and Populate (only if OCR successful)
    if (recognizedText != null) {
      _parseTextAndPopulate(recognizedText);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR ไม่สามารถอ่านข้อความได้')),
        );
    }

    // 4. Turn off loading indicator (finally block ensures this happens)
    if (mounted) {
      setState(() {
        _isProcessingOCR = false;
      });
    }
  }

  // --- ADDED: Function to perform OCR using ML Kit ---
  Future<RecognizedText?> _performOCR(File imageFile) async {
    print("Performing OCR on: ${imageFile.path}");
    TextRecognizer? textRecognizer;
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      textRecognizer = TextRecognizer(); // Default recognizer for Latin & Thai
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      print(
        "OCR processing complete. Found ${recognizedText.blocks.length} blocks.",
      );
      return recognizedText;
    } catch (e) {
      print("Error performing OCR: $e");
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR Processing Error: $e')));
      return null;
    } finally {
      // Ensure recognizer is closed
      try {
        await textRecognizer?.close();
        print("TextRecognizer closed.");
      } catch (e) {
        print("Error closing text recognizer: $e");
      }
    }
  }

  // --- ADDED: Function to parse OCR results and update controllers ---
  // ****** IMPORTANT: Adjust this logic based on your actual label formats! ******
  void _parseTextAndPopulate(RecognizedText recognizedText) {
    String extractedName = '';
    String extractedDescription = '';
    String extractedQuantity = ''; // Store only digits

    String fullText = recognizedText.text;
    final lines = fullText.split('\n');

    print("--- Starting OCR Parsing ---");
    print("Full Text:\n$fullText");
    print("--------------------------");

    bool descContext = false;
    List<String> potentialDescLines = [];

    for (int i = 0; i < lines.length; i++) {
      String tl = lines[i].trim();
      if (tl.isEmpty) continue;
      String ltl = tl.toLowerCase();
      print("Processing Line: '$tl'");

      // --- 1. Check for Quantity ---
      if (extractedQuantity.isEmpty) {
        RegExp qtyRegex = RegExp(
          r'(\d+)\s*(เม็ด|แคปซูล|ช้อน|มล|มก|ซีซี|ml|mg|g|cc|tablet|capsule)',
          caseSensitive: false,
        );
        Match? qtyMatch = qtyRegex.firstMatch(tl);
        if (qtyMatch != null) {
          extractedQuantity = qtyMatch.group(1) ?? '';
          print("Found Quantity (Regex): '$extractedQuantity'");
          // continue; // Optional: Don't check this line for other fields?
        } else if (ltl.startsWith('จำนวน') || ltl.startsWith('ขนาดบรรจุ')) {
          RegExp numRegex = RegExp(r'\d+');
          Match? numMatch = numRegex.firstMatch(tl);
          if (numMatch != null) {
            extractedQuantity = numMatch.group(0) ?? '';
            print("Found Quantity (Keyword): '$extractedQuantity'");
          }
        } else if (ltl.contains('ครั้งละ')) {
          RegExp numRegex = RegExp(r'\d+');
          Match? numMatch = numRegex.firstMatch(tl);
          if (numMatch != null) {
            extractedQuantity = numMatch.group(0) ?? '';
            print("Found Quantity (Keyword ครั้งละ): '$extractedQuantity'");
          }
        }
      }

      // --- 2. Check for Name ---
      if (extractedName.isEmpty) {
        if (ltl.startsWith('ชื่อยา') || ltl.startsWith('ยาชื่อ')) {
          extractedName =
              tl
                  .substring(
                    tl.indexOf(':') != -1
                        ? tl.indexOf(':') + 1
                        : (tl.startsWith('ยา ') ? 'ยา '.length : 0),
                  )
                  .trim();
          print("Found Name (Keyword): '$extractedName'");
          continue;
        }
        // Heuristic: Uppercase line, possibly with MG/G, not containing instruction keywords
        else if (RegExp(r'^[A-Z\s\d\.\(\)]+$').hasMatch(tl) ||
            tl.contains(RegExp(r'\d+\s*(MG|G|มก)', caseSensitive: false))) {
          if (!ltl.contains('ครั้งละ') &&
              !ltl.contains('วันละ') &&
              !ltl.contains('รับประทาน') &&
              !ltl.contains('สรรพคุณ') &&
              !ltl.contains('วิธีใช้')) {
            extractedName = tl;
            print("Found Name (Heuristic CAPS/MG): '$extractedName'");
            continue;
          }
        }
      }

      // --- 3. Check for Description ---
      List<String> descKeywords = [
        'สรรพคุณ',
        'ข้อบ่งใช้',
        'วิธีใช้',
        'indication',
        'usage',
        'รับประทาน',
        'ทาน',
        'กิน',
        'เมื่อมีอาการ',
        'แก้ไข้',
        'รายละเอียด',
      ];
      bool lineIsDescKeyword = descKeywords.any(
        (keyword) => ltl.startsWith(keyword),
      );

      if (lineIsDescKeyword) {
        descContext = true; // Start collecting description lines
        print("Desc Keyword Found: '$tl'");
        String descPart =
            tl
                .substring(
                  tl.indexOf(':') != -1
                      ? tl.indexOf(':') + 1
                      : descKeywords
                          .firstWhere((k) => ltl.startsWith(k))
                          .length,
                )
                .trim();
        if (descPart.isNotEmpty) potentialDescLines.add(descPart);
        continue; // Move to next line
      }

      // If description context is active, add lines unless it looks like a new section
      if (descContext) {
        if (ltl.startsWith('คำเตือน') ||
            ltl.startsWith('การเก็บ') ||
            ltl.startsWith('ผลิตโดย') ||
            tl.contains(RegExp(r'^\d+$'))) {
          descContext = false; // Stop description context
        } else {
          potentialDescLines.add(tl);
          print("Added potential Desc Line: '$tl'");
        }
      }
    } // End loop

    extractedDescription = potentialDescLines.join('\n').trim();
    print(
      "Final Description: ${extractedDescription.substring(0, math.min(50, extractedDescription.length))}...",
    );

    // Fallback for Name if still empty and first line exists
    if (extractedName.isEmpty &&
        lines.isNotEmpty &&
        !lines[0].trim().toLowerCase().contains('ครั้งละ')) {
      extractedName = lines[0].trim();
      print("Fallback Name (First Line): '$extractedName'");
    }

    // --- Update Controllers ---
    setState(() {
      _nameController.text = extractedName;
      _descriptionController.text = extractedDescription;
      _quantityController.text = extractedQuantity; // Already extracted digits
    });

    // --- User Feedback ---
    if (mounted) {
      /* ... SnackBar feedback ... */
      String feedback = 'สแกนเสร็จสิ้น ';
      List<String> found = [];
      if (extractedName.isNotEmpty) found.add("ชื่อยา");
      if (extractedDescription.isNotEmpty) found.add("รายละเอียด");
      if (extractedQuantity.isNotEmpty) found.add("จำนวน");
      if (found.isEmpty) {
        feedback += 'ไม่พบข้อมูล';
      } else {
        feedback += 'พบ: ${found.join(', ')} (โปรดตรวจสอบ)';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedback)));
    }
    print("--- Finished OCR Parsing ---");
  }
  // --- END OCR Function ---

  // --- Helper Widgets  ---
  Widget _buildSelectableButton(String text) {
    /* ... as before ... */
    bool isSelected = _selectedTimes.contains(text);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedTimes.remove(text);
          } else {
            _selectedTimes.add(text);
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
    /* ... as before ... */
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เพิ่มรายการยา")),
      // Use Stack for overlay
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Image Section ---
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9.0),
                          child:
                              _selectedImage != null
                                  ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                  : const Icon(
                                    Icons.image_search,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- MODIFIED Buttons to call OCR ---
                          IconButton(
                            tooltip: "ถ่ายรูป & สแกน",
                            icon: const Icon(Icons.camera_alt),
                            onPressed:
                                (_isProcessingOCR || _isSubmitting)
                                    ? null
                                    : () => _scanAndPopulateFields(
                                      ImageSource.camera,
                                    ),
                          ),
                          IconButton(
                            tooltip: "เลือกรูป & สแกน",
                            icon: const Icon(Icons.image),
                            onPressed:
                                (_isProcessingOCR || _isSubmitting)
                                    ? null
                                    : () => _scanAndPopulateFields(
                                      ImageSource.gallery,
                                    ),
                          ),
                          // --- ADDED OCR SCAN BUTTON ---
                          IconButton(
                            tooltip: "สแกนรายละเอียดจากรูปภาพ (OCR)",
                            icon: const Icon(
                              Icons.document_scanner_outlined,
                              color: Colors.blueAccent,
                            ), // Scanner icon
                            onPressed:
                                (_isProcessingOCR || _isSubmitting)
                                    ? null
                                    // Calls the OCR function, default to gallery (can offer choice later)
                                    : () => _scanAndPopulateFields(
                                      ImageSource.gallery,
                                    ),
                          ),
                          // --- END ADDED OCR SCAN BUTTON ---
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- Form Fields ---
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "ชื่อยา",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: "รายละเอียด / สรรพคุณ",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  minLines: 2,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: "จำนวนที่กิน",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.onetwothree),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "หน่วย",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        value: _selectedOption,
                        hint: const Text("เลือกหน่วย"),
                        items:
                            const [
                                  "เม็ด",
                                  "แคปซูล",
                                  "ช้อนชา",
                                  "ช้อนโต๊ะ",
                                  "มิลลิลิตร",
                                  "กรัม",
                                  "ซีซี",
                                ]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        validator:
                            (value) => value == null ? 'กรุณาเลือกหน่วย' : null,
                        onChanged:
                            (value) => setState(() => _selectedOption = value),
                      ),
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
                const SizedBox(height: 16),
                const Text(
                  "ช่วงเวลาการกินยา",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.8,
                  children:
                      const [
                        "ก่อนอาหาร",
                        "หลังอาหาร",
                        "เช้า",
                        "กลางวัน",
                        "เย็น",
                        "ก่อนนอน",
                      ].map((time) => _buildSelectableButton(time)).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  "เวลาที่ระบุ (ถ้ามี)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3.8,
                  children: [
                    _buildTimePickerField("เช้า", _morningTimeController),
                    _buildTimePickerField("กลางวัน", _noonTimeController),
                    _buildTimePickerField("เย็น", _eveningTimeController),
                    _buildTimePickerField("ก่อนนอน", _beforebedTimeController),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon:
                        _isSubmitting
                            ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.save_alt_outlined),
                    label: Text(
                      _isSubmitting ? "กำลังบันทึก..." : "บันทึกข้อมูลยา",
                    ),
                    // Disable submit button during OCR processing or submitting
                    onPressed:
                        (_isProcessingOCR || _isSubmitting)
                            ? null
                            : _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // --- Loading Indicator Overlay for OCR ---
          if (_isProcessingOCR)
            Container(
              color: Colors.black.withOpacity(0.6), // Darker overlay
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "กำลังอ่านข้อมูลจากรูปภาพ...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // --- End Loading Indicator ---
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.greenAccent,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Add Med',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Reminders'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (index == 1) {
            /* Already here? */
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ReminderViewPage()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          }
        },
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
      ),
    );
  }
} // End _InputmedState
