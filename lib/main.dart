import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:medicineproject/screens/inputmed.dart';
import 'package:medicineproject/screens/reminder.dart';
import 'package:medicineproject/screens/reminderView.dart';
import 'package:medicineproject/screens/profile.dart';
import 'package:medicineproject/notificationHelper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import plugin
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:medicineproject/loginscreens/loginpage.dart';
import 'package:medicineproject/screens/editmed.dart';

// --- Global Key ---
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// --- Top-level parseMedicineTimes ---
List<TimeOfDay> parseMedicineTimes(String timesString) {
  /* ... keep as is ... */
  List<TimeOfDay> parsedTimes = [];
  if (timesString.isEmpty) {
    return parsedTimes;
  }
  final DateFormat format = DateFormat("h:mm a", "en_US");
  final List<String> timeEntries = timesString.split(',');
  for (String entry in timeEntries) {
    final parts = entry.trim().split(' at ');
    if (parts.length == 2 && parts[1].isNotEmpty) {
      try {
        final String timeStr = parts[1].trim();
        final DateTime parsedDateTime = format.parse(timeStr);
        parsedTimes.add(TimeOfDay.fromDateTime(parsedDateTime));
      } catch (e) {
        print("Error parsing time entry '$entry': $e");
      }
    }
  }
  return parsedTimes;
}

// --- Store Launch Notification Details ---
NotificationAppLaunchDetails? notificationAppLaunchDetails;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // --- Check for Notification Launch Details BEFORE runApp ---
  notificationAppLaunchDetails = await NotificationHelper.getLaunchDetails();
  // --- Initialize Helper (without context initially) ---
  await NotificationHelper.init(); // Initialize plugin basics early
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use the key defined globally
      debugShowCheckedModeBanner: false,
      title: 'Medical App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.blue[50],
        // fontFamily: 'YourFont', // Example
      ), // Ensure closing parenthesis for ThemeData
      // --- ADDED LOCALIZATION SETUP ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // For iOS style widgets
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('th', ''), // Thai
        // Add other locales your app supports if needed
      ],
      // Optionally set a default locale if needed
      // locale: const Locale('th', ''),
      // --- END LOCALIZATION SETUP ---

      // Home can be HomeScreen directly now
      home: const LoginPage(),

      // Define routes if using named navigation
      routes: {
        // Example: You might fetch data first and then pass it
        // '/reminder': (context) => const ReminderPage(
        //       /* This route definition won't work well for passing dynamic data */
        //       medicineId: '', medicineName: 'N/A', description: '',
        //       quantity: '', unit: '', notificationId: 0,
        //     ),
      },
    );
  }
}

// --- Medicine Model (Ensure 'unit' field is added) ---
class Medicine {
  final String id;
  final String name;
  final String description;
  final String mealTimes;
  final String times;
  final String quantity;
  final String unit;
  final String imageUrl;
  final String startDate; // <-- ADDED Field
  final String endDate;   // <-- ADDED Field

  Medicine({
    required this.id,
    required this.name,
    required this.description,
    required this.mealTimes,
    required this.times,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    required this.startDate, // <-- ADDED to constructor
    required this.endDate,   // <-- ADDED to constructor
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'N/A',
      description: json['description'] ?? '',
      mealTimes: json['mealTimes'] ?? '',
      times: json['times'] ?? '',
      quantity: json['quantity']?.toString() ?? '0', // Assuming backend sends number
      unit: json['unit'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      startDate: json['startDate']?.toString() ?? '', // <-- ADDED Parsing
      endDate: json['endDate']?.toString() ?? '',     // <-- ADDED Parsing
    );
  }
}
// --- End Medicine Model ---

// --- fetchMedicines (Keep as is) ---
Future<List<Medicine>> fetchMedicines() async {
  /* ... keep as is ... */
  final url = Uri.parse('http://10.0.2.2:8080/medicines');
  print("Fetching medicines from: $url");
  try {
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    print(
      "--- Raw JSON Response from /medicines (Status: ${response.statusCode}) ---",
    );
    print(utf8.decode(response.bodyBytes));
    print("----------------------------------------");
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Medicine.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load medicines (Status code: ${response.statusCode})',
      );
    }
  } catch (e) {
    print("Error fetching medicines: $e");
    throw Exception('Error connecting to server: $e');
  }
}

// --- HomeScreen Widget ---
class HomeScreen extends StatefulWidget {
  /* ... keep as is ... */
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Medicine>>? _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _loadDataAndSchedule();
    // --- Handle navigation if app was launched from notification ---
    _handleNotificationLaunch();
  }

  // --- NEW: Handle launch navigation ---
  void _handleNotificationLaunch() {
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final response = notificationAppLaunchDetails!.notificationResponse;
      print("App launched by notification tap. Payload: ${response?.payload}");
      if (response?.payload != null && response!.payload!.isNotEmpty) {
        // Schedule navigation AFTER the first frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print("Attempting navigation from launch details...");
          NotificationHelper.navigateToReminderFromPayload(response.payload!);
        });
      }
      // Clear the details after handling
      notificationAppLaunchDetails = null;
    }
  }

  void _loadDataAndSchedule() {
    /* ... keep as is ... */
    final future = fetchMedicines()
        .then((medicines) {
          _scheduleAllNotifications(medicines);
          return medicines;
        })
        .catchError((error) {
          print("Error loading/scheduling data: $error");
          throw error;
        });
    if (mounted) {
      setState(() {
        _medicinesFuture = future;
      });
    } else {
      _medicinesFuture = future;
    }
  }

  Future<void> _refreshMedicines() async {
    /* ... keep as is ... */
    print("Refreshing medicines list...");
    _loadDataAndSchedule();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _scheduleAllNotifications(List<Medicine> medicines) async {
    /* ... keep as is, ensure 'unit' is passed ... */
    print("Attempting to schedule notifications...");
    await NotificationHelper.cancelAllNotifications();
    int notificationScheduledCount = 0;
    for (final medicine in medicines) {
      if (medicine.id.isEmpty) {
        print(
          "Skipping scheduling for medicine '${medicine.name}' due to empty ID.",
        );
        continue;
      }
      int baseId = medicine.id.hashCode.abs() % 100000;
      List<TimeOfDay> timesToSchedule = parseMedicineTimes(medicine.times);
      print(
        "Parsed times for ${medicine.name} (ID: ${medicine.id}): $timesToSchedule",
      );
      for (int i = 0; i < timesToSchedule.length; i++) {
        TimeOfDay time = timesToSchedule[i];
        int uniqueNotificationId = (baseId * 10) + i;
        try {
          /* ADD PAYLOAD DEBUG PRINT HERE IF NEEDED */
          await NotificationHelper.scheduleSingleMedicineNotification(
            notificationId: uniqueNotificationId,
            medicineId: medicine.id,
            medicineName: medicine.name,
            quantity: medicine.quantity,
            unit: medicine.unit,
            description: medicine.description,
            time: time,
          );
          notificationScheduledCount++;
        } catch (e) {
          print(
            "Error scheduling notification $uniqueNotificationId for ${medicine.name}: $e",
          );
        }
      }
    }
    print(
      "Attempted to schedule $notificationScheduledCount total notifications.",
    );
  }

  @override
  Widget build(BuildContext context) {
    /* ... keep as is ... */
    return Scaffold(
      backgroundColor: Colors.teal[200],
      appBar: AppBar(
        backgroundColor: Colors.greenAccent,
        title: const Text(
          'Somchai Chaitae',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMedicines,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 45,
                backgroundColor: Colors.teal,
                child: Icon(
                  Icons.person_outline,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'My Medications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const TimeDisplay(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<List<Medicine>>(
                  future: _medicinesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Error loading medicines:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No medicine data found.'),
                        ),
                      );
                    } else {
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final medicine = snapshot.data![index];
                          return MedicineBox(
                            medicine: medicine,
                            onDelete: _refreshMedicines,
                          );
                        },
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
            _refreshMedicines();
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Inputmed()),
            ).then((_) => _refreshMedicines());
          } else if (index == 2) {
            /* Needs data */
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReminderViewPage()),
            );
          } else if (index == 3) {
            Navigator.push(
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
}
// --- End Home Screen ---

// --- Medicine Box (Keep as is) ---
class MedicineBox extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onDelete;

  const MedicineBox({
    super.key,
    required this.medicine,
    required this.onDelete,
  });

void _navigateToEditPage(BuildContext context) {
  
  Navigator.push(
    context,
    MaterialPageRoute(
      // passing the current medicine data
      builder: (context) => EditMedicinePage(initialMedicine: medicine),
    ),
  ).then((updateWasSuccessful) {
     // This code runs *after* the EditMedicinePage is popped
     if (updateWasSuccessful == true) {
         print("Returned from successful edit, refreshing list via callback.");
         onDelete(); // Call the refresh callback passed from HomeScreen
     } else {
          print("Returned from edit, no update detected or save failed.");
     }
  });
}
// 

  Future<void> _deleteMedicine(BuildContext context) async {
    if (medicine.id.isEmpty) {
      print('Error: Cannot delete medicine "${medicine.name}" with empty ID.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ข้อผิดพลาด: ไม่พบ ID ของยา")),
      );
      return;
    }
    final url = Uri.parse('http://10.0.2.2:8080/medicines/${medicine.id}');
    print('Attempting DELETE request to: $url');
    try {
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 10));
      print('Delete Response Status Code: ${response.statusCode}');
      print('Delete Response Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("ลบยา '${medicine.name}' แล้ว")));
        onDelete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "ลบยา '${medicine.name}' ไม่สำเร็จ: ${response.statusCode} ${response.body}",
            ),
          ),
        );
      }
    } catch (e) {
      print('Error during delete request for ${medicine.name}: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาดในการลบยา: $e")));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // แสดงรูปภาพเล็กๆ และเพิ่ม GestureDetector เพื่อให้ผู้ใช้สามารถกดดูรูปใหญ่ได้
            if (medicine.imageUrl.isNotEmpty)
              GestureDetector(
                onTap: () {
                  // เมื่อกดที่รูปภาพจะเปิด Dialog เพื่อดูรูปใหญ่
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return Dialog(
                        child: InteractiveViewer(
                          child: Image.network(
                            'http://10.0.2.2:8080/medicines/${medicine.id}/image',
                            fit: BoxFit.contain, // ปรับให้รูปภาพพอดีกับขนาด
                          ),
                        ),
                      );
                    },
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'http://10.0.2.2:8080/medicines/${medicine.id}/image',
                    width: 50, // กำหนดขนาดของรูปภาพ
                    height: 50,
                    fit: BoxFit.cover,
                    loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      } else {
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                    : null,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ชื่อยา: ${medicine.name.isNotEmpty ? medicine.name : 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (medicine.description.isNotEmpty)
                    Text('สรรพคุณ: ${medicine.description}'),
                  if (medicine.times.isNotEmpty)
                    Text('เวลา: ${medicine.times}'),
                  if (medicine.quantity.isNotEmpty)
                    Text(
                      'จำนวน: ${medicine.quantity} ${medicine.unit ?? ''}'
                          .trim(),
                    ),
                ],
              ),
            ),
            // --- EDIT BUTTON ADDED 
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.blueGrey), // Edit Icon
            iconSize: 26,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4), // Adjusted padding
            tooltip: 'แก้ไข ${medicine.name}',
            onPressed: () {
                _navigateToEditPage(context); // Call navigation function
            },
          ),
          // --- END EDIT BUTTON ---
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              iconSize: 24,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              tooltip: 'Delete ${medicine.name}',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('ยืนยันการลบ'),
                      content: Text(
                        'คุณต้องการลบยา "${medicine.name}" ใช่หรือไม่?',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('ยกเลิก'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        TextButton(
                          child: const Text(
                            'ลบ',
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _deleteMedicine(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- End Medicine Box ---

// --- TimeDisplay (Keep as is) ---
class TimeDisplay extends StatefulWidget {
  /* ... */
  const TimeDisplay({super.key});
  @override
  _TimeDisplayState createState() => _TimeDisplayState();
}

class _TimeDisplayState extends State<TimeDisplay> {
  /* ... keep as is ... */
  String _currentTime = '';
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _currentTime = _formatDateTime(DateTime.now());
    _updateTime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  void _updateTime() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = _formatDateTime(DateTime.now());
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentTime,
      style: const TextStyle(fontSize: 16, color: Colors.teal),
    );
  }
}
// --- End Clock Display ---