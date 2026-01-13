import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'leave_application_screen.dart';
import 'leave_history_screen.dart';
import 'leave_approval_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _studentPages = [
    const LeaveApplicationScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<Widget> _teacherPages = [
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<Widget> _adminPages = [
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<String> _studentTitles = ['Apply Leave', 'My History'];
  final List<String> _teacherTitles = ['Pending Requests', 'Leave History'];
  final List<String> _adminTitles = ['All Requests', 'Leave History'];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final pages = user?.isStudent == true
        ? _studentPages
        : user?.isTeacher == true
        ? _teacherPages
        : _adminPages;

    final titles = user?.isStudent == true
        ? _studentTitles
        : user?.isTeacher == true
        ? _teacherTitles
        : _adminTitles;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: user?.isAdmin == true
            ? [
                const NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings),
                  label: 'Admin',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.approval),
                  label: 'Requests',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ]
            : [
                const NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Apply',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
      ),
    );
  }
}
