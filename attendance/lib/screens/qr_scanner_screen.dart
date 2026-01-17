import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  String _lastScannedData = '';
  bool _hasError = false;
  String _errorMessage = '';
  bool _permissionGranted = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted || status.isLimited) {
      setState(() {
        _permissionGranted = true;
        _permissionChecked = true;
      });
    } else {
      // Request permission
      final result = await Permission.camera.request();
      setState(() {
        _permissionGranted = result.isGranted;
        _permissionChecked = true;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    final List<String?> rawValues = barcodes
        .map((e) => e.rawValue)
        .whereType<String>()
        .toList();

    for (final code in rawValues) {
      if (code != null && code != _lastScannedData) {
        _lastScannedData = code;
        _processQRCode(code);
        break;
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Parse QR code data
      final Map<String, dynamic> data = jsonDecode(qrData);

      // session_id can be int or string in QR code, handle both
      final sessionId = data['session_id']?.toString() ?? '';
      final sessionName = data['session_name']?.toString() ?? 'Unknown Session';
      final location = data['location']?.toString() ?? '';

      if (sessionId.isEmpty) {
        throw Exception('Invalid QR code: missing session ID');
      }

      // Mark attendance via API
      final authProvider = ref.read(authProviderProvider);
      final apiService = ApiService(authProvider: authProvider);

      await apiService.markAttendance(sessionId: sessionId);

      if (mounted) {
        _showSuccessDialog(sessionName, location);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog(String sessionName, String location) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Attendance Marked!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session: $sessionName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (location.isNotEmpty)
              Text(
                'Location: $location',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            const Text(
              'Your attendance has been successfully recorded.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _lastScannedData = '';
      _hasError = false;
      _errorMessage = '';
      _isProcessing = false;
    });
  }

  void _retryAfterError() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isProcessing = false;
      _lastScannedData = '';
    });
  }

  Future<void> _requestPermission() async {
    final result = await Permission.camera.request();
    setState(() {
      _permissionGranted = result.isGranted;
      _permissionChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking permission
    if (!_permissionChecked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show permission denied UI
    if (!_permissionGranted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan QR Code'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'To scan QR codes for attendance, the app needs access to your camera.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.camera),
                  label: const Text('Grant Camera Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Open App Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main scanner UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            onPressed: () async {
              await _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepPurple),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Position the QR code within the scanner frame to mark your attendance.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // Scanner Area
          Expanded(
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),

                // Scanner overlay
                Container(
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepPurple, width: 4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    width: 250,
                    height: 250,
                  ),
                ),

                // Loading overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          const Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error overlay
                if (_hasError)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan Failed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _retryAfterError,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom info
          Container(
            padding: const EdgeInsets.all(16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Tip: Ensure good lighting for better scanning',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
