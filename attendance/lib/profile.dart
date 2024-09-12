import 'package:flutter/material.dart';
import 'package:attendance/homescreen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:attendance/main.dart'; // Assuming MyApp is in main.dart

class ProfilePage extends StatelessWidget {
  final storage = FlutterSecureStorage();

  void _onClockIconPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
    // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => ClockPage()));
  }

  void _onProfileIconPressed(BuildContext context) {
    // This is the current page, so you might want to show a message
    print('Profile icon pressed');
  }

  void _onAccountIconPressed(BuildContext context) {
    // Handle the action for the Account icon
    print('Account icon pressed');
    // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => AccountPage()));
  }

  void _onLogoutPressed(BuildContext context) async {
    // Clear storage keys
    await storage.delete(key: 'token');
    await storage.delete(key: 'fcmToken');
    
    // Navigate to login screen and remove all previous routes
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>  LoginPage()),
      
    );

    print('Logout button pressed and storage cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFD7AA), // Light orange color
              Color(0xFFFFE7C5), // Lighter cream color
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _onLogoutPressed(context),
                icon: Icon(Icons.logout), // Adding a logout icon to the button
                label: Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  primary: Colors.red, // Background color
                  onPrimary: Colors.white, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12), // Button padding
                  elevation: 5, // Button shadow
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Clock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              _onClockIconPressed(context);
              break;
            case 1:
              _onProfileIconPressed(context);
              break;
            case 2:
              _onAccountIconPressed(context);
              break;
          }
        },
      ),
    );
  }
}
