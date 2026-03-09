import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../config/location_config.dart';
import '../providers/auth_provider.dart';
import 'face_registration_screen.dart';

class BiometricAttendanceScreen extends ConsumerStatefulWidget {
  final String qrToken;

  const BiometricAttendanceScreen({super.key, required this.qrToken});

  @override
  ConsumerState<BiometricAttendanceScreen> createState() =>
      _BiometricAttendanceScreenState();
}

class _BiometricAttendanceScreenState
    extends ConsumerState<BiometricAttendanceScreen> {
  late CameraController _cameraController;
  Future<void>? _cameraInitializer;
  late BiometricAttendanceService _biometricService;

  bool _isProcessing = false;
  bool _isCapturing = false;
  String _statusMessage = "Align your face in the frame";
  Position? _currentPosition;
  bool _locationFetched = false;
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    // Get auth provider from context and initialize service
    final authProvider = ref.read(authProviderProvider);
    _biometricService = BiometricAttendanceService(
      apiService: ApiService(authProvider: authProvider),
      authProvider: authProvider,
    );
    _initializeCamera();
    _checkAndRequestLocationPermission();
  }

  @override
  void dispose() {
    try {
      _cameraController.dispose();
    } catch (e) {
      print('Error disposing camera controller: $e');
    }
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
    
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showErrorDialog(
          "Camera permission is required for biometric attendance",
        );
        return;
      }

      // Get front camera
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.veryHigh, // Use veryHigh for better quality
        enableAudio: false,
      );

      _cameraInitializer = _cameraController.initialize();
      setState(() {});
    } catch (e) {
      print('Camera initialization error: $e');
      _showErrorDialog("Failed to initialize camera");
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    if (!mounted) return;

    setState(() {
      _isRequestingPermission = true;
      _statusMessage = "Checking location permissions...";
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isRequestingPermission = false;
        });
        _showLocationErrorDialog(
          "GPS is disabled",
          "Please enable GPS/Location services to mark attendance.",
          openSettings: true,
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isRequestingPermission = false;
          });
          _showLocationErrorDialog(
            "Location permission denied",
            "Location permission is required for biometric attendance. Please grant permission to continue.",
            showRetry: true,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isRequestingPermission = false;
        });
        _showLocationErrorDialog(
          "Location permission permanently denied",
          "Please enable location permission in app settings to continue.",
          openSettings: true,
        );
        return;
      }

      // Permission granted, now get location
      await _getCurrentLocation();
    } catch (e) {
      print('Permission check error: $e');
      if (!mounted) return;
      setState(() {
        _isRequestingPermission = false;
      });
      _showLocationErrorDialog(
        "Permission error",
        "Failed to check location permissions: $e",
        showRetry: true,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = "Getting your location...";
        _isRequestingPermission = false;
      });

      final position = await _biometricService.getCurrentLocation();
      if (!mounted) return;

      if (position != null) {
        setState(() {
          _currentPosition = position;
          _locationFetched = true;
          _statusMessage = "Align your face in the frame";
        });
      } else {
        _showLocationErrorDialog(
          "Failed to get location",
          "Unable to get your current location. Please ensure GPS is enabled and try again.",
          showRetry: true,
        );
      }
    } catch (e) {
      print('Location error: $e');
      if (!mounted) return;
      _showLocationErrorDialog(
        "Location error",
        "Failed to get your location: $e",
        showRetry: true,
      );
    }
  }

  void _showLocationErrorDialog(
    String title,
    String message, {
    bool showRetry = false,
    bool openSettings = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkAndRequestLocationPermission();
              },
              child: const Text('Retry'),
            ),
          if (openSettings)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                AppSettings.openAppSettings(type: AppSettingsType.location);
              },
              child: const Text('Open Settings'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to QR scanner
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndVerify() async {
    print('=== CAPTURE AND VERIFY STARTED ===');
    print('_isProcessing: $_isProcessing');
    print('_currentPosition: $_currentPosition');

    // Check if user is a student and validate location
    final authProvider = ref.read(authProviderProvider);
    final user = authProvider.currentUser;
    if (user?.isStudent == true && LocationConfig.enforceLocationCheck) {
      final locationService = LocationService();

      // Check if user is within allowed location
      final isWithinAllowedLocation = await locationService
          .isWithinAllowedLocation();

      if (!isWithinAllowedLocation) {
        // Get detailed location status message
        final locationMessage = await locationService
            .getLocationStatusMessage();

        if (mounted) {
          _showErrorDialog('Location access denied: $locationMessage');
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
    print('mounted: $mounted');

    if (_isProcessing || _currentPosition == null || !mounted) {
      print('Early return - conditions not met');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isCapturing = true;
      _statusMessage = "Capturing face...";
    });

    try {
      print('Taking picture...');
      // Capture image
      final XFile image = await _cameraController.takePicture();
      print('Image captured successfully: ${image.path}');

      final bytes = await image.readAsBytes();
      print('Image bytes read: ${bytes.length} bytes');

      // Try to improve image quality - use higher quality if possible
      print(
        'Image quality check - bytes: ${bytes.length}, should be > 500KB for good quality',
      );

      // Convert to base64
      final imageBase64 = base64Encode(bytes);
      print('Image converted to base64: ${imageBase64.length} characters');

      // Additional image preprocessing to improve server-side face detection
      print('Applying image preprocessing for better server compatibility...');

      // The server might be doing face matching (comparing with registered face)
      // rather than just face detection. Let's ensure we send the best possible image.
      print('Note: Server may be doing face MATCHING vs face DETECTION');
      print(
        'This means it compares current face with previously registered face',
      );

      if (!mounted) {
        print('Not mounted after capture, returning');
        return;
      }

      setState(() {
        _statusMessage = "Verifying face...";
      });

      if (!mounted) {
        print('Not mounted after capture, returning');
        return;
      }

      // Detect faces before proceeding
      print('Detecting faces...');
      final faces = await _biometricService.detectFacesFromBytes(bytes);
      print('Faces detected: ${faces.length}');

      if (!mounted) {
        print('Not mounted after face detection, returning');
        return;
      }

      if (!_biometricService.isFaceValid(faces)) {
        print('Face validation failed');
        setState(() {
          _statusMessage =
              "No face detected or multiple faces detected. Please try again.";
        });
        return;
      }

      print('Face validation passed');

      if (!mounted) {
        print('Not mounted before API call, returning');
        return;
      }

      setState(() {
        _statusMessage = "Marking attendance...";
      });

      print('Calling markBiometricAttendance...');
      print('qrToken: ${widget.qrToken}');
      print('latitude: ${_currentPosition!.latitude}');
      print('longitude: ${_currentPosition!.longitude}');

      // Mark biometric attendance
      final result = await _biometricService.markBiometricAttendance(
        qrToken: widget.qrToken,
        imageBase64: imageBase64,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      print('API result: $result');

      if (!mounted) {
        print('Not mounted after API call, returning');
        return;
      }

      if (result['success'] == true) {
        print('Success! Showing success dialog');
        _showSuccessDialog(
          result['message'] ?? "Attendance marked successfully!",
        );
      } else {
        print('Failed: ${result['message']}');
        _showErrorDialog(result['message'] ?? "Failed to mark attendance");
      }
    } catch (e, stackTrace) {
      print('Biometric attendance error: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      _showErrorDialog("Failed to mark attendance: ${e.toString()}");
    } finally {
      print('=== CAPTURE AND VERIFY ENDED ===');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCapturing = false;
          _statusMessage = "Align your face in the frame";
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (message.contains('No face registered')) ...[
              const SizedBox(height: 16),
              const Text(
                'Please register your face first:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Go to Home screen'),
              const Text('2. Tap on "Register Face"'),
              const Text('3. Follow the instructions to register your face'),
              const Text('4. Then try biometric attendance again'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (message.contains('No face registered'))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close error dialog
                Navigator.of(context).pop(); // Go to home screen
              },
              child: const Text('Go to Home'),
            ),
          if (message.contains('No face registered'))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close error dialog
                _navigateToFaceRegistration();
              },
              child: const Text('Register Face'),
            ),
        ],
      ),
    );
  }

  void _navigateToFaceRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FaceRegistrationScreen()),
    );
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
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close this dialog
              _navigateToFaceRegistration(); // Go to face registration
            },
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Biometric Attendance'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Status message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_locationFetched)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Location verified',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  )
                else if (_isRequestingPermission)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Requesting location permission...',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Location not available',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Camera preview
          Expanded(
            child: FutureBuilder<void>(
              future: _cameraInitializer,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 64,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera initialization failed',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      // Camera preview
                      Center(child: CameraPreview(_cameraController)),

                      // Face overlay guide
                      Center(
                        child: Container(
                          width: 250,
                          height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isCapturing
                                  ? Colors.green
                                  : Colors.white54,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(125),
                          ),
                          child: _isCapturing
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(123),
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // Loading overlay
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Processing...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }
              },
            ),
          ),

          // Capture button
          Container(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed:
                  (_isProcessing ||
                      _currentPosition == null ||
                      _isRequestingPermission)
                  ? null
                  : _captureAndVerify,

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt),
                  const SizedBox(width: 8),
                  Text(_isProcessing ? 'Processing...' : 'Capture & Verify'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
