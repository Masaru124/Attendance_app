import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../config/location_config.dart';
import 'biometric_attendance_screen.dart';

class QrScannerScreen extends ConsumerWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _QrScannerScreen();
  }
}

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  late MobileScannerController _controller;
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
    try {
      print('Checking camera permission...');
      final status = await Permission.camera.status;
      print('Camera permission status: $status');

      if (status.isGranted || status.isLimited) {
        if (mounted) {
          setState(() {
            _permissionGranted = true;
            _permissionChecked = true;
          });
        }
      } else {
        print('Requesting camera permission...');
        final result = await Permission.camera.request();
        print('Camera permission result: $result');

        if (mounted) {
          setState(() {
            _permissionGranted = result.isGranted || result.isLimited;
            _permissionChecked = true;
          });
        }
      }
    } catch (e) {
      print('Error checking camera permission: $e');
      if (mounted) {
        setState(() {
          _permissionChecked = true;
          _permissionGranted = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return;
    }

    final scannedData = capture.barcodes.first.rawValue ?? '';

    if (scannedData == _lastScannedData) {
      return;
    }

    setState(() {
      _lastScannedData = scannedData;
      _hasError = false;
      _errorMessage = '';
    });

    _processQrCode(scannedData);
  }

  void _processQrCode(String qrData) {
    try {
      final sessionData = jsonDecode(qrData);

      if (sessionData is Map && sessionData.containsKey('session_id')) {
        final Map<String, dynamic> stringKeyedMap = {};
        sessionData.forEach((key, value) {
          if (key is String) {
            stringKeyedMap[key] = value;
          }
        });
        _showAttendanceOptionsDialog(stringKeyedMap);
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid QR code format';
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to parse QR code: $e';
      });
    }
  }

  void _showAttendanceOptionsDialog(Map<String, dynamic> sessionData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.deepPurple),
            const SizedBox(width: 8),
            const Text('Attendance Options'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session: ${sessionData['session_name'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose attendance method:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.qr_code_scanner,
                color: Colors.deepPurple,
              ),
              title: const Text('Traditional QR Scan'),
              subtitle: const Text('Mark attendance with QR code only'),
              onTap: () {
                Navigator.of(context).pop();
                _markTraditionalAttendance(sessionData);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.face, color: Colors.deepPurple),
              title: const Text('Biometric Attendance'),
              subtitle: const Text('QR + Face + Location verification'),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToBiometricAttendance(sessionData);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _markTraditionalAttendance(Map<String, dynamic> sessionData) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = ProviderContainer().read(authProviderProvider);
      final apiService = ApiService(authProvider: authProvider);
      final locationService = LocationService();

      // Check if user is a student and validate location
      final user = authProvider.currentUser;
      if (user?.isStudent == true && LocationConfig.enforceLocationCheck) {
        // Check if user is within allowed location
        final isWithinAllowedLocation = await locationService
            .isWithinAllowedLocation();

        if (!isWithinAllowedLocation) {
          // Get detailed location status message
          final locationMessage = await locationService
              .getLocationStatusMessage();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location access denied: $locationMessage'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      // Check if user has registered face (for students)
      if (user?.isStudent == true && !(user?.faceRegistered ?? false)) {
        if (mounted) {
          _showFaceRegistrationDialog();
        }
        return;
      }

      await apiService.markAttendance(
        sessionId: sessionData['session_id'].toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showFaceRegistrationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Face Registration Required'),
        content: const Text(
          'You need to register your face before marking attendance. Please go to the home screen and tap on "Register Face".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  int _cameraKey = 0; // Used to force MobileScanner rebuild

  Future<void> _navigateToBiometricAttendance(
    Map<String, dynamic> sessionData,
  ) async {
    try {
      // Stop and dispose the QR scanner camera before navigating
      await _controller.stop();
      await _controller.dispose();

      // Add delay to allow camera hardware to fully release
      await Future.delayed(const Duration(milliseconds: 1000));

      final qrToken = jsonEncode(sessionData);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BiometricAttendanceScreen(qrToken: qrToken),
        ),
      );

      // Reinitialize the QR scanner camera when returning
      if (mounted) {
        try {
          _controller = MobileScannerController();
          _cameraKey++; // Force MobileScanner to rebuild with new controller
          setState(() {});
        } catch (e) {
          print('Failed to reinitialize QR scanner camera: $e');
          // Try again after a longer delay
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _controller = MobileScannerController();
            _cameraKey++;
            setState(() {});
          }
        }
      }
    } catch (e) {
      print('Error in biometric navigation: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to open biometric attendance: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionChecked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Scanner'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking camera permission...'),
            ],
          ),
        ),
      );
    }

    if (!_permissionGranted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Scanner'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera permission required',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant camera permission to scan QR codes',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkCameraPermission,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Grant Permission'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  AppSettings.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            key: ValueKey(_cameraKey),
            controller: _controller,
            onDetect: _onDetect,
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          if (_hasError)
            Positioned(
              bottom: 50,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_isProcessing && !_hasError)
            Positioned(
              bottom: 50,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_scanner, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'Scan QR Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Position QR code within the frame',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
