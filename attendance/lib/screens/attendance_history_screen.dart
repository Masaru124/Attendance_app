import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AttendanceRecord {
  final int id;
  final String sessionName;
  final DateTime date;
  final String status;
  final String? location;
  final String? checkInTime;
  final String? checkOutTime;

  AttendanceRecord({
    required this.id,
    required this.sessionName,
    required this.date,
    required this.status,
    this.location,
    this.checkInTime,
    this.checkOutTime,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      sessionName: json['session_name'] ?? 'Unknown Session',
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      status: json['status'] ?? 'PRESENT',
      location: json['location'],
      checkInTime: json['check_in_time'],
      checkOutTime: json['check_out_time'],
    );
  }

  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Colors.green;
      case 'ABSENT':
        return Colors.red;
      case 'LATE':
        return Colors.orange;
      case 'EXCUSED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return Icons.check_circle;
      case 'ABSENT':
        return Icons.cancel;
      case 'LATE':
        return Icons.access_time;
      case 'EXCUSED':
        return Icons.event_note;
      default:
        return Icons.help;
    }
  }
}

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'ALL';
  final List<String> _filterOptions = [
    'ALL',
    'PRESENT',
    'ABSENT',
    'LATE',
    'EXCUSED',
  ];

  // Statistics
  int _totalPresent = 0;
  int _totalAbsent = 0;
  int _totalLate = 0;
  double _attendanceRate = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendance();
    });
  }

  Future<void> _loadAttendance() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = ref.read(authProviderProvider);
      final apiService = ApiService(authProvider: authProvider);

      final records = await apiService.getMyAttendance();

      final List<AttendanceRecord> attendanceRecords = records
          .map((e) => AttendanceRecord.fromJson(e))
          .toList();

      // Calculate statistics
      _totalPresent = attendanceRecords
          .where((r) => r.status.toUpperCase() == 'PRESENT')
          .length;
      _totalAbsent = attendanceRecords
          .where((r) => r.status.toUpperCase() == 'ABSENT')
          .length;
      _totalLate = attendanceRecords
          .where((r) => r.status.toUpperCase() == 'LATE')
          .length;

      final total = attendanceRecords.length;
      _attendanceRate = total > 0 ? (_totalPresent / total) * 100 : 0;

      setState(() {
        _attendanceRecords = attendanceRecords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AttendanceRecord> get _filteredRecords {
    if (_selectedFilter == 'ALL') {
      return _attendanceRecords;
    }
    return _attendanceRecords
        .where((r) => r.status.toUpperCase() == _selectedFilter)
        .toList();
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
    final authProvider = ref.watch(authProviderProvider);
    final isTeacherOrAdmin =
        authProvider.currentUser?.role == UserRole.teacher ||
        authProvider.currentUser?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacherOrAdmin ? 'Attendance Records' : 'My Attendance'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAttendance,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Statistics Card
                _buildStatsCard(),
                const SizedBox(height: 8),
                // Filter chip
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                              },
                      ),
                      const Spacer(),
                      Text(
                        '${_filteredRecords.length} records',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Attendance list
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No attendance records found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFilter != 'ALL'
                                    ? 'Try a different filter'
                                    : 'Your attendance will appear here',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAttendance,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _filteredRecords.length,
                            itemBuilder: (context, index) {
                              final record = _filteredRecords[index];
                              return _buildAttendanceCard(record);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  label: 'Present',
                  value: _totalPresent.toString(),
                  color: Colors.green,
                ),
                _buildStatItem(
                  label: 'Absent',
                  value: _totalAbsent.toString(),
                  color: Colors.red,
                ),
                _buildStatItem(
                  label: 'Late',
                  value: _totalLate.toString(),
                  color: Colors.orange,
                ),
                Column(
                  children: [
                    Text(
                      '${_attendanceRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Text(
                      'Rate',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
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

  Widget _buildAttendanceCard(AttendanceRecord record) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: record.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                record.statusIcon,
                size: 24,
                color: record.statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.sessionName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${record.date.day}/${record.date.month}/${record.date.year}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (record.checkInTime != null) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.checkInTime!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (record.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          record.location!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: record.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                record.status,
                style: TextStyle(
                  color: record.statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
