import 'dart:io'; // เพิ่มตรงนี้
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http
import 'package:medicineproject/notificationHelper.dart';
import 'dart:convert'; // Import convert

class ReminderPage extends StatefulWidget {
  final String medicineId;
  final String medicineName;
  final String description;
  final String quantity;
  final String unit;
  final int notificationId;

  const ReminderPage({
    super.key,
    required this.medicineId,
    required this.medicineName,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.notificationId,
  });

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  bool _isDeleting = false;
  bool _isSnoozing = false;
  bool _isLogging = false; // Added state for logging action

  // --- NEW: Helper Function to Send Log Data ---
  Future<bool> _sendLog(String action) async {
    if (_isLogging) return false; // Prevent double logging

    setState(() { _isLogging = true; });
    print('Sending log: $action for ${widget.medicineName}');

    final logUrl = Uri.parse('http://10.0.2.2:8080/logs'); // Your log endpoint
    final logData = {
      "medicineId": widget.medicineId,
      "medicineName": widget.medicineName,
      "action": action, // "TAKEN" or "POSTPONED"
      "logTimestamp": DateTime.now().toIso8601String(), // Current time in standard format
    };

    try {
      final response = await http.post(
        logUrl,
        headers: {"Content-Type": "application/json; charset=UTF-8"},
        body: jsonEncode(logData),
      ).timeout(const Duration(seconds: 10));

      setState(() { _isLogging = false; }); // Logging attempt finished

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Log ($action) saved successfully.');
        return true; // Indicate success
      } else {
        print('Failed to save log ($action): ${response.statusCode} ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถบันทึก Log ได้: ${response.statusCode}')),
          );
        }
        return false; // Indicate failure
      }
    } catch (e) {
      print('Error sending log ($action): $e');
      if (mounted) {
        setState(() { _isLogging = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก Log: $e')),
        );
      }
      return false; // Indicate failure
    }
  }
  // --- END Helper Function ---

  // Function to get the image URL
  String getImageUrl() {
    final baseUrl = Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
    return '$baseUrl/medicines/${widget.medicineId}/image';
  }

  // --- Action for "OK" (ตกลง) Button ---
  Future<void> _handleOkAction() async {
    if (_isLogging || _isSnoozing) return; 

    bool logSuccess = await _sendLog("TAKEN"); // Log as "TAKEN"

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ยืนยันการกินยา '${widget.medicineName}' แล้ว")),
      );
      Navigator.of(context).pop();
    }
  }

  // --- Action for "Postpone" (เลื่อนไปก่อน) Button ---
  Future<void> _handlePostponeAction() async {
    if (_isSnoozing || _isLogging) return;

    bool logSuccess = await _sendLog("POSTPONED"); // Log as "POSTPONED"

    setState(() {_isSnoozing = true;});
    await NotificationHelper.cancelNotification(widget.notificationId);

    final String payload = jsonEncode({
      'id': widget.medicineId, 'name': widget.medicineName, 'description': widget.description,
      'quantity': widget.quantity, 'unit': widget.unit, 'notificationId': widget.notificationId,
    });

    await NotificationHelper.scheduleSnoozeNotification(
        notificationId: widget.notificationId,
        medicineName: widget.medicineName,
        quantity: widget.quantity,
        unit: widget.unit,
        payload: payload,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("เลื่อนการแจ้งเตือน '${widget.medicineName}' ไปอีก 5 นาที")),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    String dosageInfo = "${widget.quantity} ${widget.unit ?? ''}".trim();
    bool buttonsDisabled = _isLogging || _isSnoozing;

    return Scaffold(
      backgroundColor: Colors.teal[200],
      appBar: AppBar(
        title: const Text('แจ้งเตือนกินยา', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.greenAccent, elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.of(context).pop(), ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // รูปภาพยา
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                getImageUrl(),
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: Icon(Icons.medication, size: 80, color: Colors.white70),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // กล่องข้อมูลยา
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ถึงเวลากินยา ${widget.medicineName}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildDetailRow('ชื่อยา:', widget.medicineName),
                  const SizedBox(height: 8),
                  _buildDetailRow('รายละเอียด:', widget.description),
                  const SizedBox(height: 8),
                  _buildDetailRow('กินครั้งละ:', dosageInfo),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: buttonsDisabled ? null : _handleOkAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: _isLogging || _isSnoozing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                        : const Text('ตกลง', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: buttonsDisabled ? null : _handlePostponeAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: _isLogging || _isSnoozing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                        : const Text('เลื่อนไปก่อน', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
