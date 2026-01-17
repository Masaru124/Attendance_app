import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../providers/home_tab_controller.dart';
import '../models/user.dart';
import '../models/leave_request.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when the screen becomes visible
    // This ensures we have the latest leave status
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final authProvider = ref.read(authProviderProvider);
    final leaveProvider = ref.read(leaveProviderProvider);

    try {
      await leaveProvider.fetchLeaveStats();
      if (authProvider.currentUser?.role == UserRole.student) {
        await leaveProvider.fetchMyLeaves();
      } else if (authProvider.currentUser?.role == UserRole.teacher ||
          authProvider.currentUser?.role == UserRole.admin) {
        await leaveProvider.fetchPendingLeaves();
      }
    } catch (e) {
      // Silently fail - dashboard will show partial data
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = ref.watch(authProviderProvider);
    final leaveProvider = ref.watch(leaveProviderProvider);
    final user = authProvider.currentUser;
    final isAdmin = user?.role == UserRole.admin;
    final isTeacher = user?.role == UserRole.teacher;
    final isStudent = user?.role == UserRole.student;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            elevation: 4,
            color: Colors.deepPurple,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          user?.name[0].toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.name ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user?.role
                                        .toString()
                                        .split('.')
                                        .last
                                        .toUpperCase() ??
                                    'STUDENT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
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

          // Stats Cards
          if (leaveProvider.stats != null) ...[
            const Text(
              'Leave Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    leaveProvider.stats!.total.toString(),
                    Colors.deepPurple,
                    Icons.event_note,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending',
                    leaveProvider.stats!.pending.toString(),
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Approved',
                    leaveProvider.stats!.approved.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Rejected',
                    leaveProvider.stats!.rejected.toString(),
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Quick Actions Section
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Role-based Quick Actions
          if (isStudent) ...[
            _buildQuickActionCard(
              context,
              'Apply for Leave',
              'Submit a new leave request',
              Icons.event_note,
              Colors.blue,
              () => _navigateToApplyLeave(context),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              context,
              'Scan QR Code',
              'Mark your attendance',
              Icons.qr_code_scanner,
              Colors.purple,
              () => _navigateToQRScanner(context),
            ),
          ],

          if (isTeacher) ...[
            _buildQuickActionCard(
              context,
              'Pending Requests',
              'Review leave requests',
              Icons.approval,
              Colors.orange,
              () => _navigateToPendingRequests(context),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              context,
              'Attendance Sessions',
              'Create and manage QR codes',
              Icons.qr_code_2,
              Colors.purple,
              () => _navigateToAttendanceSessions(context),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              context,
              'View History',
              'See all leave history',
              Icons.history,
              Colors.blue,
              () => _navigateToHistory(context),
            ),
          ],

          if (isAdmin) ...[
            _buildQuickActionCard(
              context,
              'Manage Users',
              'View and manage users',
              Icons.people,
              Colors.deepPurple,
              () => _navigateToAdminPanel(context),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              context,
              'Pending Requests',
              'Review leave requests',
              Icons.approval,
              Colors.orange,
              () => _navigateToPendingRequests(context),
            ),
            const SizedBox(height: 12),
            _buildQuickActionCard(
              context,
              'Attendance Sessions',
              'Create and manage QR codes',
              Icons.qr_code_2,
              Colors.purple,
              () => _navigateToAttendanceSessions(context),
            ),
          ],

          const SizedBox(height: 24),

          // Recent Activity Section
          if (leaveProvider.myLeaves.isNotEmpty) ...[
            const Text(
              'Recent Leave Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...leaveProvider.myLeaves
                .take(3)
                .map(
                  (leave) => Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: leave.statusColor.withOpacity(0.2),
                        child: Icon(
                          leave.status == LeaveStatus.pending
                              ? Icons.pending
                              : leave.status == LeaveStatus.approved
                              ? Icons.check
                              : Icons.close,
                          color: leave.statusColor,
                        ),
                      ),
                      title: Text(leave.dateRangeString),
                      subtitle: Text(
                        leave.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: leave.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          leave.statusString,
                          style: TextStyle(
                            color: leave.statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],

          const SizedBox(height: 16),

          // Empty state for students with no leaves
          if (isStudent &&
              leaveProvider.myLeaves.isEmpty &&
              !leaveProvider.isLoading) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No leave requests yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToApplyLeave(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Apply for Leave'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToApplyLeave(BuildContext context) {
    ref.read(homeTabControllerProvider).goToApplyLeave();
  }

  void _navigateToQRScanner(BuildContext context) {
    ref.read(homeTabControllerProvider).goToQRScanner();
  }

  void _navigateToPendingRequests(BuildContext context) {
    ref.read(homeTabControllerProvider).goToPendingRequests();
  }

  void _navigateToHistory(BuildContext context) {
    ref.read(homeTabControllerProvider).goToLeaveHistory();
  }

  void _navigateToAdminPanel(BuildContext context) {
    ref.read(homeTabControllerProvider).goToAdminPanel();
  }

  void _navigateToAttendanceSessions(BuildContext context) {
    ref.read(homeTabControllerProvider).goToAttendanceSessions();
  }
}
