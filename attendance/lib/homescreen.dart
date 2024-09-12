import 'package:attendance/profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:geolocator/geolocator.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.dmSansTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.black, displayColor: Colors.black),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isClockedIn = false;
  bool _onBreak = false;
  DateTime? _clockInTime;
  DateTime? _breakStartTime;
  Duration _totalWorkedTime = Duration.zero;
  Duration _totalBreakTime = Duration.zero;
   Timer? _timer;

  

  final String postApiUrl = 'https://attendancebe.qcomm.co/app/user/';
   final String getApiUrl = 'https://attendancebe.qcomm.co/app/user/daily_attendance_list/';
   
  // final url = Uri.parse('http://192.168.3.178:8000/app/login/');
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String _token = '';
    List<Map<String, dynamic>> records = [];
    String _locationMessage = "";

  @override
  void initState() {
    super.initState();
    _getTokenFromStorage();
    
     PushNotificationService().initialize();
    
  }

Future<void> _getCurrentLocation(BuildContext context) async {
  bool permissionGranted = false;

  while (!permissionGranted) {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // Show a pop-up dialog when permission is denied
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Location Permission Required'),
              content: Text(
                  'This app needs location access to function properly. Please allow location access.'),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );

        continue; // Loop continues until permission is granted
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Show a pop-up dialog when permission is permanently denied
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Location Permission Permanently Denied'),
            content: Text(
                'Location permissions are permanently denied. Please enable them from settings.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      return;
    }

    permissionGranted = true;
  }

  // If permissions are granted, proceed with getting the location
  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  print("Latitude: ${position.latitude}, Longitude: ${position.longitude}");
}
  Future<void> _getTokenFromStorage() async {
    _token = await _secureStorage.read(key: 'token') ?? '';
    print('Retrieved token: $_token'); // Print the token for debugging
     
    if (_token.isNotEmpty) {
      // Call the API if the token is available
      _sendGetRequest();
    } else {
      print('Authorization token is not available');
      // You might want to redirect to login or show an error message
    }
  }



  Future<void> _saveButtonStates() async {
  
  }

  Future<bool> _sendPostRequest(String action, {double? latitude, double? longitude}) async {
    try {
      final response = await http.post(
        Uri.parse('$postApiUrl/$action'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Authorization": "Bearer $_token",
        },
        body: jsonEncode(<String, dynamic>{
            'latitude': latitude,
          'longitude': longitude,
        }),
      );
 if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      bool status = responseData['status']; // Assuming the API response has a 'status' field
      
      if (status) {
        print('POST request successful: ${response.body}');
        return true; // Return true if status is true
      } else {
        print('POST request failed with false status: ${response.body}');
      }
    } else {
      print('Failed to send POST request: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (e) {
    print('Error sending POST request: $e');
  }
  return false; // Return false if anything fails
  }

   String _formatElapsedTime(Duration elapsed) {
    int hours = elapsed.inHours;
    int minutes = elapsed.inMinutes.remainder(60);
    int seconds = elapsed.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


   Future<void> _sendGetRequest() async {
    try {
      final response = await http.get(
        Uri.parse(getApiUrl),
        headers: <String, String>{
          "Authorization": "Bearer $_token",
        },
      );
       if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      if (jsonData['status']) {
         _updateStateFromApi(jsonData['current_state']);
        setState(() {
               records = List<Map<String, dynamic>>.from(jsonData['data']);
             
        });
      }
    } else {
      print('Failed to load data');
    }
      

      if (response.statusCode == 200) {
        print('GET request successful: ${response.body}');
      } else {
        print('Failed to send GET request: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error sending GET request: $e');
    }
    
  }
 void _updateStateFromApi(Map<String, dynamic> currentState) {
  if (currentState['state'] == 'Checked In') {
    setState(() {
      _isClockedIn = true;
       _onBreak = false;
        double checkedInSeconds = currentState['checked_in_seconds'] ?? 0.0;
      Duration workedDuration = Duration(seconds: checkedInSeconds.round());

      // Calculate clockInTime by subtracting workedDuration from now
      _clockInTime = DateTime.now().subtract(workedDuration);

      _startTimer();
    });
  } else if (currentState['state'] == 'Break Started') {
    setState(() {
      _onBreak = true;
      _isClockedIn = true;
       double checkedInSeconds = currentState['checked_in_seconds'] ?? 0.0;
      Duration workedDuration = Duration(seconds: checkedInSeconds.round());

      // Calculate clockInTime by subtracting workedDuration from now
      _clockInTime = DateTime.now().subtract(workedDuration);
       double breakStartSeconds = currentState['checked_in_seconds'] ?? 0.0;
      Duration breakDuration = Duration(seconds: breakStartSeconds.round());

      // Calculate breakStartTime by subtracting breakDuration from now
      _breakStartTime = DateTime.now();

      _stopTimer();
    });
  } else {
    setState(() {
      _isClockedIn = false;
      _onBreak = false;
      _stopTimer();
    });
  }
}

  String _calculateTotalHoursWorked(String checkIn, String checkOut) {
    DateTime checkInTime = DateTime.parse(checkIn);
    DateTime checkOutTime = DateTime.parse(checkOut);

    Duration workedDuration = checkOutTime.difference(checkInTime);
    int hours = workedDuration.inHours;
    int minutes = workedDuration.inMinutes.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} total hrs';
  }

  // Method to format date
  String _formatDate(String date) {
    DateTime parsedDate = DateFormat('dd-MM-yyyy').parse(date);
    return DateFormat('MMMM dd, yyyy').format(parsedDate);
  }
  String _formatTimeToLocal(String time) {
    DateTime utcTime = DateTime.parse(time).toUtc();
    // Convert UTC time to local time
    DateTime localTime = utcTime.toLocal();
    return DateFormat.jm().format(localTime); // Format time as 'h:mm a'
  }
    void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
      });
    });
  }

  void _resumeTimerAfterBreak() {
    if (_breakStartTime == null) return;

    final breakDuration = DateTime.now().difference(_breakStartTime!);
    setState(() {
      _clockInTime = _clockInTime?.add(breakDuration);
      _onBreak = false;
      _startTimer();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }



  void _clockIn() async {
 // Get current location
    await _getCurrentLocation(context);
    
    // Extract latitude and longitude
    double? latitude;
    double? longitude;
    if (_locationMessage.isNotEmpty && _locationMessage.contains('Latitude')) {
      latitude = double.parse(_locationMessage.split('Latitude: ')[1].split(',')[0]);
      longitude = double.parse(_locationMessage.split('Longitude: ')[1]);
    }
  
    // Send POST request with location data
    bool success = await _sendPostRequest('check_in/', latitude: latitude, longitude: longitude);
  
    if (success) {
      setState(() {
        _isClockedIn = true;
        _clockInTime = DateTime.now();
        _startTimer();
      });
    }
  }








  
  

  void _clockOut() async {
    bool success = await _sendPostRequest('check_out/');
    
   
   if (success) {
    await _sendGetRequest();
    
    setState(() {
      if (_clockInTime != null) {
        _totalWorkedTime += DateTime.now().difference(_clockInTime!);
      }
      _isClockedIn = false;
      _onBreak = false;
      _stopTimer();
      _showSummaryDialog();
    });
  } 

  }

  void _takeBreak() async {
    bool success = await _sendPostRequest('start_break/');
  
  if (success) {
    setState(()  {
       
      _onBreak = true;
      _breakStartTime = DateTime.now();
      _stopTimer();
    });
    await _sendGetRequest();

  }
  }

  void _endBreak() async {
    bool success = await _sendPostRequest('end_break/');
  
  if (success) {
    setState(()  {
       
      if (_breakStartTime != null) {
        _totalBreakTime += DateTime.now().difference(_breakStartTime!);
      }
      _onBreak = false;
      _resumeTimerAfterBreak();
      
    });
     await _sendGetRequest();

  
  }
  }

  void _showSummaryDialog() {
    Duration effectiveWorkTime = _totalWorkedTime - _totalBreakTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Daily Summary'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clock In: ${_formatTime(_clockInTime)}'),
              Text('Clock Out: ${_formatTime(DateTime.now())}'),
              Text('Total Worked Time: ${_formatDuration(_totalWorkedTime)}'),
              Text('Total Break Time: ${_formatDuration(_totalBreakTime)}'),
              Text('Effective Work Time: ${_formatDuration(effectiveWorkTime)}'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'N/A';
    return '${time.hour}:${time.minute}:${time.second}';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
  
  String _formattedDate() {
    return DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
  }

    void _onClockIconPressed() {
    // Handle Clock icon press
    print('Clock icon pressed');
  }

  void _onProfileIconPressed() {
    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfilePage()),
    );
    
  }

  void _onAccountIconPressed() {
    // Handle Account icon press
    print('Account icon pressed');
  }

  @override
  Widget build(BuildContext context) {

       return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFD7AA), // Light orange color
                    Color(0xFFFFFFFF), // Lighter cream color
                  ],
                   stops: [0.0, 0.7],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 43.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 6.0, horizontal: 10.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _formattedDate(),
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                         _isClockedIn ? 'You are clocked in' : 'Good morning',
                        style: GoogleFonts.dmSans(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                 _isClockedIn ? 'Have a nice day' : "Let's get to work!",
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height: 20),
              // Timer Display
              if (_isClockedIn) 
                Text(
                  _formatElapsedTime(DateTime.now().difference(_clockInTime!)),
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 400,
                    child: _isClockedIn
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _clockOut,
                                  style: ElevatedButton.styleFrom(
                                    primary: Colors.transparent,
                                    side: BorderSide(color: Colors.black, width: 2),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    
                                      
                                    
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Clock Out',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 18, color: Colors.black),
                                  ),
                                ),
                              ),
                              
                              
                              SizedBox(width: 8),
                              Expanded(
                                child: _onBreak
                                    ? ElevatedButton(
                                        onPressed: _endBreak,
                                        style: ElevatedButton.styleFrom(
                                          primary: Colors.orange,
                                          padding: EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          elevation: 5,
                                        ),
                                        child: Text(
                                          'End Break',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 18,
                                              color: Colors.black),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _takeBreak,
                                        style: ElevatedButton.styleFrom(
                                          primary: Colors.orange,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          elevation: 5,
                                        ),
                                        child: Text(
                                          'Take a break',
                                          style: GoogleFonts.dmSans(
                                              fontSize: 18,
                                              color: Colors.black),
                                        ),
                                      ),
                              ),
                            ],
                          ) 
                        : ElevatedButton(
                            onPressed: _clockIn,
                            style: ElevatedButton.styleFrom(
                              primary: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              'Clock In',
                              style: GoogleFonts.dmSans(fontSize: 20, color: Colors.black),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                
                 Expanded(
child: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          final totalHours = record['time_worked']; 
          final formattedDate = _formatDate(record['date']);
          final checkInTime = _formatTimeToLocal(record['check_in']);
          final checkOutTime = _formatTimeToLocal(record['check_out']);
          

          return Padding(
             padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                 border: Border.all(
                        color: Colors.grey, // Lightly black border color
                        width: 1.0, // Border width
                      ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                         maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      AutoSizeText(
                         '$totalHours ',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                         minFontSize: 12,
                                maxFontSize: 16,
                         maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'In & Out',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      AutoSizeText(
                        '$checkInTime-$checkOutTime',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                         minFontSize: 12,
                         maxFontSize: 16,
                         maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Prevent overflow
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
          ),
              ],
            ),
          ),
        ],
      ),
       bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time,
            color: Colors.orange,),
            label: 'Clock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person,
            color: Colors.orange,),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle,
            color: Colors.orange,),
            label: 'Account',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              _onClockIconPressed();
              break;
            case 1:
              _onProfileIconPressed();
              break;
            case 2:
              _onAccountIconPressed();
              break;
          }
        },
      ),
    );
  }
}


class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> initialize() async {
    // Request permissions for iOS
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize local notifications for iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    // Combine Android and iOS initialization settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get the FCM token and save it securely
      String? FcmToken = await _fcm.getToken();
      if (FcmToken != null) {
        print('FCM Token: $FcmToken');
        await _secureStorage.write(key: 'FcmToken', value: FcmToken);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received a message while in foreground: ${message.notification?.title}');
        print('Message Data: ${message.data}');

        // Save message data if needed
        // await _secureStorage.write(key: 'messageData', value: message.data.toString());

        // Show a local notification
        _showNotification(message);
      });

      // Handle notification clicks
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Notification clicked! App opened.');
        print('Clicked Message Data: ${message.data}');

        // Handle the message data when app is opened by a notification
        _handleNotificationClick(message);
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS notification details
    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails();

    // Combine Android and iOS notification details
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      message.notification?.title ?? 'No Title', // Notification Title
      message.notification?.body ?? 'No Body', // Notification Body
      platformChannelSpecifics, // Notification Details
    );
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Handle the notification click
    // Extract information from message.data and perform navigation or other actions
    print('Notification Clicked with Data: ${message.data}');
  }
}