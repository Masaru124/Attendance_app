import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_provider.dart';
import '../models/leave_request.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLeaves();
    });
  }

  Future<void> _fetchLeaves() async {
    final authProvider = context.read<AuthProvider>();
    final leaveProvider = context.read<LeaveProvider>();
    await leaveProvider.fetchMyLeaves(authProvider.token!);
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave History'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLeaves),
        ],
      ),
      body: leaveProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : leaveProvider.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${leaveProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchLeaves,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : leaveProvider.myLeaves.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No leave applications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Apply for your first leave!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchLeaves,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: leaveProvider.myLeaves.length,
                itemBuilder: (context, index) {
                  final leave = leaveProvider.myLeaves[index];
                  return LeaveHistoryCard(leave: leave);
                },
              ),
            ),
    );
  }
}

class LeaveHistoryCard extends StatelessWidget {
  final LeaveRequest leave;

  const LeaveHistoryCard({super.key, required this.leave});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    leave.dateRangeString,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: leave.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: leave.statusColor),
                  ),
                  child: Text(
                    leave.statusString,
                    style: TextStyle(
                      color: leave.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              leave.reason,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${leave.totalDays} day(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Applied: ${leave.createdAt.day}/${leave.createdAt.month}/${leave.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            if (leave.status != LeaveStatus.pending &&
                leave.reviewerName != null) ...[
              const SizedBox(height: 8),
              Text(
                leave.status == LeaveStatus.approved
                    ? 'Approved by: ${leave.reviewerName}'
                    : 'Rejected by: ${leave.reviewerName}',
                style: TextStyle(
                  fontSize: 12,
                  color: leave.statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
