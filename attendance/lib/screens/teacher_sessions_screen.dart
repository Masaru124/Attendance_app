import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_provider.dart';
import '../providers/create_session_dialog_provider.dart';
import '../models/attendance_session.dart';
import '../widgets/create_session_dialog.dart';

class TeacherSessionsScreen extends ConsumerStatefulWidget {
  const TeacherSessionsScreen({super.key});

  @override
  ConsumerState<TeacherSessionsScreen> createState() =>
      _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends ConsumerState<TeacherSessionsScreen> {
  final _sessionNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _radiusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Late timing options
  TimeOfDay? _selectedLateUntilTime;
  final bool _useTimeOnly = false;

  Future<void> _selectLateTime(
    void Function(void Function()) setDialogState,
  ) async {
    print('=== DEBUG: Time picker opened ===');
    print('Current _selectedLateUntilTime: $_selectedLateUntilTime');

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedLateUntilTime ?? TimeOfDay(hour: 9, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    print('Time picker result: $picked');

    if (picked != null && mounted) {
      print('Setting new time: $picked');
      setDialogState(() {
        _selectedLateUntilTime = picked;
      });
      print('Updated _selectedLateUntilTime: $_selectedLateUntilTime');
    } else {
      print('Time picker cancelled or not mounted');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProviderProvider).fetchSessions();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showCreateSessionDialog() async {
    print('=== DEBUG: Creating session dialog ===');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CreateSessionDialog(),
    );

    if (result != null) {
      // Create session with dialog data
      await _createSessionWithData(result);
    }
  }

  Future<void> _createSessionWithData(Map<String, dynamic> data) async {
    final sessionName = data['sessionName'] as String;
    final location = data['location'] as String?;
    final radiusText = data['radiusText'] as String?;
    final lateUntilTime = data['lateUntilTime'] as TimeOfDay?;
    final useTimeOnly = data['useTimeOnly'] as bool;

    final radius = radiusText?.isNotEmpty == true
        ? int.tryParse(radiusText!)
        : null;

    DateTime? lateUntil;
    if (useTimeOnly && lateUntilTime != null) {
      final now = DateTime.now();
      lateUntil = DateTime(
        now.year,
        now.month,
        now.day,
        lateUntilTime.hour,
        lateUntilTime.minute,
      );
    }

    try {
      await ref
          .read(attendanceProviderProvider)
          .createSession(
            sessionName: sessionName,
            location: location,
            radiusMeters: radius,
            lateUntil: lateUntil,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createSession() async {
    if (_formKey.currentState?.validate() != true) return;

    final sessionName = _sessionNameController.text.trim();
    final location = _locationController.text.trim().isEmpty
        ? null
        : _locationController.text.trim();
    final radiusText = _radiusController.text.trim();

    final radius = radiusText.isNotEmpty ? int.tryParse(radiusText) : null;

    final lateUntilTime = ref
        .read(createSessionDialogProvider.notifier)
        .selectedLateUntilTime;

    final useTimeOnly = ref
        .read(createSessionDialogProvider.notifier)
        .useTimeOnly;

    DateTime? lateUntil;
    if (useTimeOnly && lateUntilTime != null) {
      // Convert TimeOfDay to DateTime for the provider
      final now = DateTime.now();
      lateUntil = DateTime(
        now.year,
        now.month,
        now.day,
        lateUntilTime.hour,
        lateUntilTime.minute,
      );
    }

    try {
      await ref
          .read(attendanceProviderProvider)
          .createSession(
            sessionName: sessionName,
            location: location,
            radiusMeters: radius,
            lateUntil: lateUntil,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewQrCode(AttendanceSession session) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch session with QR code
    final provider = ref.read(attendanceProviderProvider);
    final sessionWithQr = await provider.getSessionWithQrCode(session.id);

    // Pop loading dialog
    if (mounted) Navigator.of(context).pop();

    // Show QR dialog with fetched data
    if (mounted && sessionWithQr != null) {
      _showQrCodeDialog(sessionWithQr);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load QR code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQrCodeDialog(AttendanceSession session) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.deepPurple),
            const SizedBox(width: 12),
            Text('QR Code Generated'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (session.qrImageBase64 != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.memory(
                    base64Decode(session.qrImageBase64!),
                    width: 200,
                    height: 200,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                session.sessionName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (session.location != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Location: ${session.location}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              if (session.radiusMeters != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Radius: ${session.radiusMeters}m',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              if (session.lateUntil != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Late Until: ${session.lateUntil}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Session ID: ${session.id}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share this QR code with students to mark attendance',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(attendanceProviderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Sessions'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchSessions(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSessionDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
      body: provider.isLoading && provider.sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error: ${provider.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchSessions(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : provider.sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No attendance sessions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a session to start taking attendance',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreateSessionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => provider.fetchSessions(),
              child: ListView.builder(
                padding: const EdgeInsets.only(
                  bottom: 80, // Space for FAB
                  top: 8,
                  left: 8,
                  right: 8,
                ),
                itemCount: provider.sessions.length,
                itemBuilder: (context, index) {
                  final session = provider.sessions[index];
                  return _buildSessionCard(session);
                },
              ),
            ),
    );
  }

  Widget _buildSessionCard(AttendanceSession session) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.sessionName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (session.location != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              session.location!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (session.radiusMeters != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.radio_button_unchecked,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${session.radiusMeters}m radius',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (session.lateUntil != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Until ${session.lateUntil}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: session.isActive
                        ? Colors.green.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.isActive ? 'Active' : 'Closed',
                    style: TextStyle(
                      color: session.isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${session.totalRecords} students marked',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  session.formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewQrCode(session),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('View QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (session.isActive)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _closeSession(session),
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Close Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Closed'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _closeSession(AttendanceSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Session?'),
        content: Text(
          'Are you sure you want to close "${session.sessionName}"? '
          'No more attendance can be marked after closing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final provider = ref.read(attendanceProviderProvider);
      final success = await provider.closeSession(session.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session closed successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close session: ${provider.error}')),
        );
      }
    }
  }
}
