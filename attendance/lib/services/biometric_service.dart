import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class BiometricAttendanceService {
  final ApiService apiService;
  final AuthProvider authProvider;

  BiometricAttendanceService({
    required this.apiService,
    required this.authProvider,
  });

  /// Request camera permissions
  Future<bool> requestCameraPermission() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }
      return true;
    } catch (e) {
      print('Camera permission error: $e');
      return false;
    }
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return true;
    } catch (e) {
      print('Location permission error: $e');
      return false;
    }
  }

  /// Get current GPS location with proper permission handling
  Future<Position?> getCurrentLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        // Try to get last known position as fallback
        return await _getLastKnownPosition();
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Try to get current position with timeout
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        print('Failed to get current position: $e');
        // Fallback to last known position
        return await _getLastKnownPosition();
      }
    } catch (e) {
      print('Location error: $e');
      return null;
    }
  }

  /// Get last known position as fallback
  Future<Position?> _getLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        print(
          'Using last known position: ${position.latitude}, ${position.longitude}',
        );
      }
      return position;
    } catch (e) {
      print('Failed to get last known position: $e');
      return null;
    }
  }

  /// Convert camera image to base64
  Future<String?> convertImageToBase64(CameraImage cameraImage) async {
    try {
      // Convert CameraImage to RGB bytes
      final rgbBytes = _convertYUV420ToRGB(cameraImage);

      // Convert to base64
      return base64Encode(rgbBytes);
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

  /// Convert YUV420 to RGB
  Uint8List _convertYUV420ToRGB(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    final rgbImage = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final yIndex = y * width + x;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        // Convert YUV to RGB
        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
            .round();
        int b = (yValue + 1.772 * (uValue - 128)).round();

        // Clamp values
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        final rgbIndex = yIndex * 3;
        rgbImage[rgbIndex] = r;
        rgbImage[rgbIndex + 1] = g;
        rgbImage[rgbIndex + 2] = b;
      }
    }

    return rgbImage;
  }

  /// Detect faces in image from bytes
  Future<List<Face>> detectFacesFromBytes(Uint8List imageBytes) async {
    try {
      print('Starting face detection from JPEG bytes...');

      // Convert JPEG bytes to UIImage for proper processing
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to byte array in RGBA format
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        print('Failed to convert image to byte data');
        return [];
      }

      final rgbaBytes = byteData.buffer.asUint8List();

      // Convert RGBA to NV21 format that ML Kit expects
      final width = image.width;
      final height = image.height;
      final nv21Bytes = _convertRGBAtoNV21(rgbaBytes, width, height);

      print(
        'Image converted: ${width}x$height, NV21 bytes: ${nv21Bytes.length}',
      );

      
      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );

   
      final options = FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: false,
        minFaceSize: 0.1, // Smaller minimum face size
        performanceMode: FaceDetectorMode.accurate,
      );

      final faceDetector = FaceDetector(options: options);
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      print('Face detection completed. Found ${faces.length} faces');
      for (int i = 0; i < faces.length; i++) {
        final face = faces[i];
        print(
          'Face $i: boundingBox=${face.boundingBox}, '
          'headEulerY=${face.headEulerAngleY}, '
          'headEulerX=${face.headEulerAngleX}',
        );
      }

      return faces;
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  /// Convert RGBA to NV21 format
  Uint8List _convertRGBAtoNV21(Uint8List rgbaBytes, int width, int height) {
    final yPlane = Uint8List(width * height);
    final uvPlane = Uint8List(width * height ~/ 2);

    int uvIndex = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final rgbaIndex = (y * width + x) * 4;
        final r = rgbaBytes[rgbaIndex];
        final g = rgbaBytes[rgbaIndex + 1];
        final b = rgbaBytes[rgbaIndex + 2];

        // Convert RGB to Y
        final yValue = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16;
        yPlane[y * width + x] = yValue.clamp(0, 255);

        // Sample U and V every 2x2 block
        if (y % 2 == 0 && x % 2 == 0) {
          final uValue = ((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128;
          final vValue = ((112 * r - 94 * g - 18 * b + 128) >> 8) + 128;

          uvPlane[uvIndex++] = uValue.clamp(0, 255);
          uvPlane[uvIndex++] = vValue.clamp(0, 255);
        }
      }
    }

    // Combine Y and UV planes
    final nv21Bytes = Uint8List(width * height + width * height ~/ 2);
    nv21Bytes.setRange(0, width * height, yPlane);
    nv21Bytes.setRange(width * height, nv21Bytes.length, uvPlane);

    return nv21Bytes;
  }

  /// Detect faces in image
  Future<List<Face>> detectFaces(CameraImage cameraImage) async {
    try {
      // Convert camera image to InputImage format
      final inputImage = await _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) return [];

      // Configure face detector
      final options = FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        enableContours: false,
        enableTracking: false,
      );

      final faceDetector = FaceDetector(options: options);
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      return faces;
    } catch (e) {
      print('Face detection error: $e');
      return [];
    }
  }

  /// Convert CameraImage to InputImage
  Future<InputImage?> _convertCameraImageToInputImage(
    CameraImage cameraImage,
  ) async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) return null;

      final plane = cameraImage.planes.map((plane) => plane.bytes).toList();

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(plane.expand((bytes) => bytes).toList()),
        metadata: InputImageMetadata(
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
          rotation: rotation,
          format: format,
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      print('InputImage conversion error: $e');
      return null;
    }
  }

 
  Future<Map<String, dynamic>> markBiometricAttendance({
    required String qrToken,
    required String imageBase64,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await apiService.markBiometricAttendance(
        qrToken: qrToken,
        imageBase64: imageBase64,
        latitude: latitude,
        longitude: longitude,
      );
      return result;
    } catch (e) {
      print('Biometric attendance error: $e');
      rethrow;
    }
  }


  Future<Map<String, dynamic>> registerFace(String imageBase64) async {
    try {
      final result = await apiService.registerFace(imageBase64);
      return result;
    } catch (e) {
      print('Face registration error: $e');
      rethrow;
    }
  }

  /// Validate face detection results
  bool isFaceValid(List<Face> faces) {
    if (faces.isEmpty) {
      return false; // No face detected
    }

    if (faces.length > 1) {
      return false; // Multiple faces detected
    }

    final face = faces.first;

    // Check face quality
    if (face.headEulerAngleY != null &&
        (face.headEulerAngleY! > 30 || face.headEulerAngleY! < -30)) {
      return false; // Face turned too much sideways
    }

    if (face.headEulerAngleX != null &&
        (face.headEulerAngleX! > 20 || face.headEulerAngleX! < -20)) {
      return false; // Face tilted too much up/down
    }

    // Check if face is large enough (good quality)
    final boundingBox = face.boundingBox;
    if (boundingBox.width < 100 || boundingBox.height < 100) {
      return false; // Face too small
    }

    return true;
  }

  /// Get distance between two GPS coordinates (in meters)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
