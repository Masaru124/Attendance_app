import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateSessionDialog extends ConsumerStatefulWidget {
  const CreateSessionDialog({super.key});

  @override
  ConsumerState<CreateSessionDialog> createState() =>
      _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<CreateSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sessionNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _radiusController = TextEditingController();

  // Late timing options
  TimeOfDay? _selectedLateUntilTime;
  bool _useTimeOnly = false;

  @override
  void dispose() {
    _sessionNameController.dispose();
    _locationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _selectLateTime() async {
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
      setState(() {
        _selectedLateUntilTime = picked;
      });
      print('Updated _selectedLateUntilTime: $_selectedLateUntilTime');
    } else {
      print('Time picker cancelled or not mounted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle, color: Colors.deepPurple),
          const SizedBox(width: 12),
          const Text('Create New Session'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name *',
                  hintText: 'e.g., CS101 Lecture',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Session name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (Optional)',
                  hintText: 'e.g., Room 301',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius in meters (Optional)',
                  hintText: 'e.g., 50',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final radius = int.tryParse(value);
                    if (radius == null || radius <= 0) {
                      return 'Please enter a valid positive number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Late Timing Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Text(
                          'Late Timing (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Option 1: No late timing
                    GestureDetector(
                      onTap: () {
                        print('=== DEBUG: No late timing tapped ===');
                        setState(() {
                          _useTimeOnly = false;
                          _selectedLateUntilTime = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: !_useTimeOnly
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _useTimeOnly
                                  ? Icons.radio_button_unchecked
                                  : Icons.radio_button_checked,
                              color: _useTimeOnly
                                  ? Colors.grey
                                  : Colors.deepPurple,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'No late timing',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Text(
                                    'Use default 9:00 AM cutoff',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Option 2: Set time only
                    GestureDetector(
                      onTap: () {
                        print('=== DEBUG: Set time only tapped ===');
                        print('Before setState - _useTimeOnly: $_useTimeOnly');
                        print(
                          'Before setState - _selectedLateUntilTime: $_selectedLateUntilTime',
                        );

                        setState(() {
                          _useTimeOnly = true;
                          _selectedLateUntilTime =
                              _selectedLateUntilTime ??
                              TimeOfDay(hour: 9, minute: 0);
                        });

                        print('After setState - _useTimeOnly: $_useTimeOnly');
                        print(
                          'After setState - _selectedLateUntilTime: $_selectedLateUntilTime',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _useTimeOnly
                                ? Colors.deepPurple
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _useTimeOnly
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _useTimeOnly
                                  ? Colors.deepPurple
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Set time only',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Text(
                                    'e.g., 9:00 AM (uses today\'s date)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_useTimeOnly) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Late Time'),
                        subtitle: Text(
                          _selectedLateUntilTime != null
                              ? '${_selectedLateUntilTime!.hour.toString().padLeft(2, '0')}:${_selectedLateUntilTime!.minute.toString().padLeft(2, '0')}'
                              : 'Select late deadline time',
                        ),
                        trailing: const Icon(Icons.arrow_drop_down),
                        onTap: _selectLateTime,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              // Return session data to caller
              Navigator.pop(context, {
                'sessionName': _sessionNameController.text.trim(),
                'location': _locationController.text.trim().isEmpty
                    ? null
                    : _locationController.text.trim(),
                'radiusText': _radiusController.text.trim(),
                'lateUntilTime': _selectedLateUntilTime,
                'useTimeOnly': _useTimeOnly,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Create Session'),
        ),
      ],
    );
  }

  // Getters for parent to access the data
  String get sessionName => _sessionNameController.text.trim();
  String? get location => _locationController.text.trim().isEmpty
      ? null
      : _locationController.text.trim();
  String? get radiusText => _radiusController.text.trim();
  TimeOfDay? get selectedLateUntilTime => _selectedLateUntilTime;
  bool get useTimeOnly => _useTimeOnly;
}
