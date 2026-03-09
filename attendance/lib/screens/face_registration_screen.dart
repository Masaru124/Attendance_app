import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import '../services/biometric_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class FaceRegistrationScreen extends ConsumerStatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  ConsumerState<FaceRegistrationScreen> createState() =>
      _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState
    extends ConsumerState<FaceRegistrationScreen> {
  late CameraController? _cameraController;
  late Future<void> _cameraInitializer;
  bool _isProcessing = false;
  bool _isCapturing = false;
  String _statusMessage = "Align your face in frame";
  late BiometricAttendanceService _biometricService;

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
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera permission
      final cameraPermission = await Permission.camera.request();

      if (!cameraPermission.isGranted) {
        _showErrorDialog("Camera permission is required for face registration");
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
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraInitializer = _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      _showErrorDialog("Failed to initialize camera");
    }
  }

  Future<void> _captureAndRegister() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _isCapturing = true;
      _statusMessage = "Capturing face...";
    });

    try {
      // Capture image
      final XFile image = await _cameraController!.takePicture();

      final bytes = await image.readAsBytes();

      setState(() {
        _statusMessage = "Detecting face...";
      });

      // Detect faces before registering
      final faces = await _biometricService.detectFacesFromBytes(bytes);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = "No face detected. Please try again.";
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _statusMessage =
              "Multiple faces detected. Please ensure only your face is visible.";
        });
        return;
      }

      // Validate face quality
      if (!_biometricService.isFaceValid(faces)) {
        setState(() {
          _statusMessage = "Face not properly aligned. Please adjust position.";
        });
        return;
      }

      // Convert to base64
      final imageBase64 = base64Encode(bytes);

      setState(() {
        _statusMessage = "Registering face...";
      });

      // Register face
      final result = await _biometricService.registerFace(imageBase64);

      if (result['success'] == true) {
        // Refresh user profile to update face registration status
        final authProvider = ref.read(authProviderProvider);
        await authProvider.refreshUserProfile();

        _showSuccessDialog(
          result['message'] ?? "Face registered successfully!",
        );
      } else {
        _showErrorDialog(result['message'] ?? "Failed to register face");
      }
    } catch (e) {
      _showErrorDialog("Failed to register face: ${e.toString()}");
    } finally {
      setState(() {
        _isProcessing = false;
        _isCapturing = false;
        _statusMessage = "Align your face in frame";
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
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
        title: const Text('Register Face'),
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
            child: Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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
                      Center(child: CameraPreview(_cameraController!)),
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
              onPressed: () {
                if (_isProcessing) {
                  return;
                }
                _captureAndRegister();
              },
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
                  Text(_isProcessing ? 'Processing...' : 'Register Face'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
