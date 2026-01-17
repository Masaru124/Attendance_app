import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/leave_provider.dart';
import '../models/leave_request.dart';

class LeaveHistoryScreen extends ConsumerStatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  ConsumerState<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends ConsumerState<LeaveHistoryScreen> {
  String _selectedFilter = 'ALL';
  final List<String> _filterOptions = [
    'ALL',
    'PENDING',
    'APPROVED',
    'REJECTED',
  ];

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLeaves();
      _fetchStats();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always refresh data when the screen becomes visible
    // This ensures we get the latest status from the server
    _fetchLeaves();
    _fetchStats();
  }

  Future<void> _fetchLeaves() async {
    if (_isRefreshing) return;

    final leaveProvider = ref.read(leaveProviderProvider);
    _isRefreshing = true;

    String? status = _selectedFilter == 'ALL' ? null : _selectedFilter;

    try {
      await leaveProvider.fetchLeaveHistory(status: status);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchStats() async {
    final leaveProvider = ref.read(leaveProviderProvider);
    await leaveProvider.fetchLeaveStats();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._filterOptions.map(
              (filter) => ListTile(
                title: Text(filter),
                leading: Radio<String>(
                  value: filter,
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    Navigator.pop(context);
                    _fetchLeaves();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveProvider = ref.watch(leaveProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leave History'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchLeaves();
              _fetchStats();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Card
          if (leaveProvider.stats != null)
            _buildStatsCard(leaveProvider.stats!),
          const SizedBox(height: 8),
          // Filter chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Filter: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Chip(
                  label: Text(_selectedFilter),
                  backgroundColor: Colors.deepPurple[100],
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: _selectedFilter == 'ALL'
                      ? null
                      : () {
                          setState(() {
                            _selectedFilter = 'ALL';
                          });
                          _fetchLeaves();
                        },
                ),
              ],
            ),
          ),
          // Leave list
          Expanded(
            child: leaveProvider.isLoading && leaveProvider.myLeaves.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : leaveProvider.error != null && leaveProvider.myLeaves.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${leaveProvider.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _fetchLeaves();
                            _fetchStats();
                          },
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
                        const Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No leave applications found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try a different filter or apply for leave!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchLeaves();
                      await _fetchStats();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: leaveProvider.myLeaves.length,
                      itemBuilder: (context, index) {
                        final leave = leaveProvider.myLeaves[index];
                        return LeaveHistoryCard(leave: leave);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(LeaveStatsData stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  label: 'Total',
                  value: stats.total.toString(),
                  color: Colors.deepPurple,
                ),
                _buildStatItem(
                  label: 'Pending',
                  value: stats.pending.toString(),
                  color: Colors.orange,
                ),
                _buildStatItem(
                  label: 'Approved',
                  value: stats.approved.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  label: 'Rejected',
                  value: stats.rejected.toString(),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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
            if (leave.reviewedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reviewed: ${leave.reviewedAt!.day}/${leave.reviewedAt!.month}/${leave.reviewedAt!.year}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
