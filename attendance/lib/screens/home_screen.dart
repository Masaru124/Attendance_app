import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import 'leave_application_screen.dart';
import 'leave_history_screen.dart';
import 'leave_approval_screen.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _statsLoaded = false;

  final List<Widget> _studentPages = [
    const DashboardScreen(),
    const LeaveApplicationScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<Widget> _teacherPages = [
    const DashboardScreen(),
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<Widget> _adminPages = [
    const DashboardScreen(),
    const LeaveApprovalScreen(),
    const LeaveHistoryScreen(),
  ];

  final List<String> _studentTitles = [
    'Dashboard',
    'Apply Leave',
    'My History',
  ];
  final List<String> _teacherTitles = [
    'Dashboard',
    'Pending Requests',
    'Leave History',
  ];
  final List<String> _adminTitles = [
    'Dashboard',
    'All Requests',
    'Leave History',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authProvider = context.read<AuthProvider>();
    final leaveProvider = context.read<LeaveProvider>();

    if (authProvider.token != null) {
      await leaveProvider.fetchLeaveStats(authProvider.token!);
      _statsLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    final pages = user?.role == 'STUDENT'
        ? _studentPages
        : user?.role == 'TEACHER'
        ? _teacherPages
        : _adminPages;

    final titles = user?.role == 'STUDENT'
        ? _studentTitles
        : user?.role == 'TEACHER'
        ? _teacherTitles
        : _adminTitles;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_currentIndex == 0)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
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
        destinations: _getNavigationDestinations(user),
      ),
    );
  }

  List<NavigationDestination> _getNavigationDestinations(User? user) {
    if (user?.role == 'STUDENT') {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          selectedIcon: Icon(Icons.add_circle),
          label: 'Apply',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: 'History',
        ),
      ];
    } else if (user?.role == 'TEACHER') {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.pending_actions),
          selectedIcon: Icon(Icons.check_circle),
          label: 'Requests',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: 'History',
        ),
      ];
    } else {
      // Admin
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.admin_panel_settings),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history),
          label: 'History',
        ),
      ];
    }
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final authProvider = context.read<AuthProvider>();
    final leaveProvider = context.read<LeaveProvider>();

    if (authProvider.token != null) {
      await leaveProvider.fetchLeaveStats(authProvider.token!);

      // Also load pending leaves for teachers/admins
      if (authProvider.currentUser?.role != 'STUDENT') {
        await leaveProvider.fetchPendingLeaves(authProvider.token!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final leaveProvider = context.watch<LeaveProvider>();
    final user = authProvider.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 48,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              user?.name ?? 'User',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Chip(
                              label: Text(user?.role ?? 'STUDENT'),
                              backgroundColor: Colors.deepPurple[100],
                              labelStyle: TextStyle(
                                color: Colors.deepPurple[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Statistics Section
          if (leaveProvider.stats != null) ...[
            const Text(
              'Leave Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatsGrid(leaveProvider.stats!),
          ],

          const SizedBox(height: 20),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(user),

          // Pending Requests (for teachers/admins)
          if (user?.role != 'STUDENT' &&
              leaveProvider.pendingLeaves.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Requests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${leaveProvider.pendingLeaves.length} pending',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...leaveProvider.pendingLeaves
                .take(3)
                .map(
                  (leave) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Colors.deepPurple,
                      ),
                      title: Text(leave.studentName),
                      subtitle: Text(leave.dateRangeString),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // Navigate to approval screen
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Review'),
                      ),
                    ),
                  ),
                ),
            if (leaveProvider.pendingLeaves.length > 3)
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to full list
                  },
                  child: const Text('View all pending requests →'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(LeaveStatsData stats) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          label: 'Total',
          value: stats.total.toString(),
          icon: Icons.assignment,
          color: Colors.deepPurple,
        ),
        _buildStatCard(
          label: 'Pending',
          value: stats.pending.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _buildStatCard(
          label: 'Approved',
          value: stats.approved.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _buildStatCard(
          label: 'Rejected',
          value: stats.rejected.toString(),
          icon: Icons.cancel,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(User? user) {
    final actions = <Map<String, dynamic>>[];

    if (user?.role == 'STUDENT') {
      actions.addAll([
        {
          'icon': Icons.add_circle,
          'label': 'Apply Leave',
          'route': '/leave/apply',
          'color': Colors.deepPurple,
        },
        {
          'icon': Icons.history,
          'label': 'My History',
          'route': '/leave/history',
          'color': Colors.blue,
        },
      ]);
    } else {
      actions.addAll([
        {
          'icon': Icons.pending_actions,
          'label': 'Review Requests',
          'route': '/leave/approve',
          'color': Colors.orange,
        },
        {
          'icon': Icons.history,
          'label': 'Leave History',
          'route': '/leave/history',
          'color': Colors.blue,
        },
      ]);
    }

    return Row(
      children: actions.asMap().entries.map((entry) {
        final action = entry.value;
        final isFirst = entry.key == 0;
        return Expanded(
          child: Card(
            elevation: 2,
            margin: EdgeInsets.only(right: isFirst ? 8 : 0),
            child: InkWell(
              onTap: () {
                // Navigate based on route
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      action['icon'] as IconData,
                      size: 36,
                      color: action['color'] as Color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
