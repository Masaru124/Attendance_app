import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/home_tab_controller.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';
import 'leave_application_screen.dart';
import 'leave_history_screen.dart';
import 'leave_approval_screen.dart';
import 'attendance_history_screen.dart';
import 'qr_scanner_screen.dart';
import 'admin_screen.dart';
import 'attendance_sessions_screen.dart';
import 'teacher_sessions_screen.dart';
import 'face_registration_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<Widget> _studentPages = [
    const DashboardScreen(),
    const LeaveApplicationScreen(),
    const LeaveHistoryScreen(),
    const QrScannerScreen(),
    const AttendanceHistoryScreen(),
    FaceRegistrationScreen(),
  ];

  final List<Widget> _teacherPages = [
    const DashboardScreen(),
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
    const TeacherSessionsScreen(),
    FaceRegistrationScreen(),
  ];

  final List<Widget> _adminPages = [
    const AdminScreen(),
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
    const AttendanceSessionsScreen(),
    FaceRegistrationScreen(),
  ];

  final List<String> _studentTitles = [
    'Dashboard',
    'Apply Leave',
    'My History',
    'Scan QR',
    'Attendance',
    'Register Face',
  ];
  final List<String> _teacherTitles = [
    'Dashboard',
    'Pending Requests',
    'Leave History',
    'Sessions',
    'Register Face',
  ];
  final List<String> _adminTitles = [
    'Admin Panel',
    'Pending Requests',
    'Leave History',
    'Sessions',
    'Register Face',
  ];

  List<Widget> get _pages {
    final authProvider = ref.read(authProviderProvider);
    final user = authProvider.currentUser;

    if (user?.role == UserRole.admin) {
      return _getFilteredPages(_adminPages, user);
    } else if (user?.role == UserRole.teacher) {
      return _getFilteredPages(_teacherPages, user);
    } else {
      return _getFilteredPages(_studentPages, user);
    }
  }

  List<String> get _titles {
    final authProvider = ref.read(authProviderProvider);
    final user = authProvider.currentUser;

    if (user?.role == UserRole.admin) {
      return _getFilteredTitles(_adminTitles, user);
    } else if (user?.role == UserRole.teacher) {
      return _getFilteredTitles(_teacherTitles, user);
    } else {
      return _getFilteredTitles(_studentTitles, user);
    }
  }

  List<String> _getFilteredTitles(List<String> originalTitles, user) {
    // Remove 'Register Face' if user has already registered their face
    if (user?.faceRegistered == true) {
      return originalTitles.where((title) => title != 'Register Face').toList();
    }
    return originalTitles;
  }

  List<Widget> _getFilteredPages(List<Widget> originalPages, user) {
    // Remove FaceRegistrationScreen if user has already registered their face
    if (user?.faceRegistered == true) {
      return originalPages
          .where((page) => page.runtimeType != FaceRegistrationScreen)
          .toList();
    }
    return originalPages;
  }

  @override
  Widget build(BuildContext context) {
    final tabController = ref.watch(homeTabControllerProvider);
    final authProvider = ref.watch(authProviderProvider);
    final user = authProvider.currentUser;
    final titles = _titles;
    final pages = _pages;

    // Ensure the index is within bounds
    final currentIndex = tabController.currentIndex < pages.length
        ? tabController.currentIndex
        : 0;

    print('=== HomeScreen Build ===');
    print('Current index: ${tabController.currentIndex}');
    print('Clamped index: $currentIndex');
    print('User role: ${user?.role}');
    print('Pages length: ${pages.length}');
    print('Current page type: ${pages[currentIndex].runtimeType}');

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          print('=== Bottom Navigation Tapped ===');
          print('Index clicked: $index');
          print('Total pages available: ${pages.length}');
          print('Current user role: ${user?.role}');
          print('Page at index: ${pages[index].runtimeType}');
          ref.read(homeTabControllerProvider).setIndex(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        items: titles.asMap().entries.map((entry) {
          return BottomNavigationBarItem(
            icon: Icon(_getIconForIndex(entry.key, user)),
            label: entry.value,
          );
        }).toList(),
      ),
    );
  }

  IconData _getIconForIndex(int index, user) {
    final isAdmin = user?.role == UserRole.admin;
    final isTeacher = user?.role == UserRole.teacher;
    final hasFaceRegistered = user?.faceRegistered == true;

    if (isAdmin || isTeacher) {
      // Adjust indices based on whether Register Face is filtered out
      final adjustedIndex = hasFaceRegistered && index >= 4 ? index + 1 : index;
      switch (adjustedIndex) {
        case 0:
          return isAdmin ? Icons.admin_panel_settings : Icons.dashboard;
        case 1:
          return Icons.approval;
        case 2:
          return Icons.history;
        case 3:
          return Icons.event_note;
        case 4:
          return Icons.face;
        case 5:
          return Icons.qr_code_2;
        default:
          return Icons.home;
      }
    } else {
      // Adjust indices based on whether Register Face is filtered out
      final adjustedIndex = hasFaceRegistered && index >= 5 ? index + 1 : index;
      switch (adjustedIndex) {
        case 0:
          return Icons.dashboard;
        case 1:
          return Icons.event_note;
        case 2:
          return Icons.history;
        case 3:
          return Icons.qr_code_scanner;
        case 4:
          return Icons.check_circle;
        case 5:
          return Icons.face;
        default:
          return Icons.home;
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = ref.read(authProviderProvider);
    await authProvider.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
