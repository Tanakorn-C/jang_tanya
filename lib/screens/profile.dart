import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Use prefix to avoid conflicts
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle; // To load font asset

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  String _notificationSound = 'เสียง 1';
  final List<String> _soundOptions = [
    'เสียง 1',
    'เสียง 2',
    'เสียง 3',
    'เสียงอื่น ๆ',
  ];
  final TextEditingController _usernameController = TextEditingController(
    text: 'LWA',
  );
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isGeneratingPdf = false; // Loading state for PDF button

  @override
  void dispose() {
    /* ... dispose controllers ... */
    _usernameController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Function to Generate PDF Report ---
  Future<void> _generatePdfReport(DateTime selectedDate) async {
    if (_isGeneratingPdf) return; // Prevent double taps

    setState(() {
      _isGeneratingPdf = true;
    });

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
    final displayDate = DateFormat(
      'dd MMMM yyyy',
      'th_TH',
    ).format(selectedDate); // Thai date format
    print('Generating report for date: $formattedDate');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('กำลังสร้างรายงานสำหรับวันที่ $formattedDate...')),
    );

    // --- Fetch Log Data from Backend ---
    List<dynamic> logData = [];
    try {
      final dataUrl = Uri.parse(
        'http://10.0.2.2:8080/logs/report?date=$formattedDate',
      );
      final response = await http
          .get(dataUrl)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        logData = json.decode(utf8.decode(response.bodyBytes));
        print('Received ${logData.length} log entries.');
        if (logData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ไม่พบข้อมูล log สำหรับวันที่ $formattedDate'),
            ),
          );
          setState(() {
            _isGeneratingPdf = false;
          });
          return;
        }
      } else {
        print('Failed to fetch log data: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถดึงข้อมูล log ได้: ${response.statusCode}'),
          ),
        );
        setState(() {
          _isGeneratingPdf = false;
        });
        return;
      }
    } catch (e) {
      print('Error fetching log data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการดึงข้อมูล log: $e')),
      );
      setState(() {
        _isGeneratingPdf = false;
      });
      return;
    }

    // --- Generate PDF Document in Flutter ---
    final pdf = pw.Document();

    // Load Thai font
    // Make sure 'fonts/ChakraPetch-Medium.ttf' exists in your project and pubspec.yaml
    final fontData = await rootBundle.load('fonts/ChakraPetch-Medium.ttf');
    final ttf = pw.Font.ttf(fontData);
    final pdfTheme = pw.ThemeData.withFont(
      base: ttf,
      bold: ttf,
    ); // Use same font for bold for simplicity

    pdf.addPage(
      pw.Page(
        theme: pdfTheme, // Apply theme with Thai font
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context pdfContext) {
              // Map log data to table rows with explicit typing
         List<List<String>> tableData = logData.map<List<String>>((log) { // Specify map output type
            // Treat log as a Map for easier access (add type cast if needed)
            final logMap = log as Map<String, dynamic>;

            String actionThai = 'ไม่ทราบ'; // Default
            if (logMap['action'] == 'TAKEN') actionThai = 'กินแล้ว';
            if (logMap['action'] == 'POSTPONED') actionThai = 'เลื่อน';

            String timeString = 'N/A';
            // Safely access and parse the timestamp
            if (logMap['logTimestamp'] is String) {
                 try {
                   timeString = DateFormat('HH:mm:ss', 'en_US') // Added locale
                     .format(DateTime.parse(logMap['logTimestamp']));
                 } catch (e) {
                   print("Error parsing log timestamp: ${logMap['logTimestamp']} - $e");
                 }
            } else {
                 print("Log timestamp is not a String: ${logMap['logTimestamp']}");
            }


            // Explicitly create and return a List<String>
            return <String>[
                timeString,
                logMap['medicineName']?.toString() ?? 'N/A', // Ensure String
                actionThai
            ];
          }).toList(); // .toList() now correctly produces List<List<String>>

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, // Align left
            children: [
              pw.Center(
                // Center the main title
                child: pw.Text(
                  'รายงานการกินยา ประจำวันที่ $displayDate', // Use Thai formatted date
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: pdfContext, // Important for table helper
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(2),
                  ),
                ),
                headerHeight: 25,
                cellHeight: 30,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['เวลาที่บันทึก', 'ชื่อยา', 'สถานะ'],
                data: tableData,
                border: pw.TableBorder.all(),
                columnWidths: const {
                  // Adjust column widths as needed
                  0: pw.FixedColumnWidth(100), // Time
                  1: pw.FlexColumnWidth(2.0), // Name (wider)
                  2: pw.FixedColumnWidth(100), // Status
                },
              ),
            ],
          );
        }, // build
      ), // Page
    ); // addPage

    // --- Save and Open the PDF ---
    try {
      final outputDir = await getApplicationDocumentsDirectory();
      final outputFile = File(
        '${outputDir.path}/medication_report_$formattedDate.pdf',
      );
      await outputFile.writeAsBytes(await pdf.save()); // Save the PDF document
      print('PDF report saved to: ${outputFile.path}');

      // Open the generated PDF
      final result = await OpenFilex.open(outputFile.path);
      print('OpenFilex result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปิดไฟล์ PDF ได้: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      print('Error saving or opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการจัดการไฟล์ PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        }); // Re-enable button
      }
    }
  }
  // --- End PDF Function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        /* ... as before ... */ title: const Text('โปรไฟล์'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (Your existing profile fields) ...
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.teal[100],
                  child: Icon(Icons.person, size: 50),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'วันที่: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    'เวลา: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildTextField('ชื่อผู้ใช้', _usernameController),
              _buildTextField('เพศ', _genderController),
              _buildTextField('อายุ', _ageController),
              _buildTextField('อีเมล', _emailController),
              _buildSoundSelection(),
              _buildTextField(
                'รหัสผ่าน',
                _passwordController,
                obscureText: true,
              ),
              SizedBox(height: 20),

              // --- PDF Report Button ---
              Center(
                child: ElevatedButton.icon(
                  icon:
                      _isGeneratingPdf
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _isGeneratingPdf
                        ? 'กำลังสร้าง...'
                        : 'สร้างรายงาน PDF ประจำวัน',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  // Disable button while generating
                  onPressed:
                      _isGeneratingPdf
                          ? null
                          : () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              locale: const Locale(
                                'th',
                                'TH',
                              ), // Optional: Set locale for DatePicker
                            );
                            if (pickedDate != null) {
                              await _generatePdfReport(
                                pickedDate,
                              ); // Await the async function
                            } else {
                              print('Date picking cancelled');
                            }
                          },
                ),
              ),

              // --- END PDF Report Button ---
              SizedBox(height: 16),
              Center(
                /* ... Edit/Save Button ... */ child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (_isEditing) {
                        /* Save logic here */
                      }
                      _isEditing = !_isEditing;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  child: Text(_isEditing ? 'บันทึก' : 'แก้ไข'),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets 
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
  }) {
    /* ... */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: _isEditing,
          obscureText: obscureText,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSoundSelection() {
    /* ... */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('เสียงแจ้งเตือน'),
        SizedBox(height: 8),
        DropdownButton<String>(
          isExpanded: true,
          value: _notificationSound,
          items:
              _soundOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
          onChanged:
              _isEditing
                  ? (value) {
                    setState(() {
                      _notificationSound = value!;
                    });
                  }
                  : null,
        ),
        SizedBox(height: 16),
      ],
    );
  }
} // End _ProfilePageState
