import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/location_config.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> hasLocationPermission() async {
    final permission = await Permission.location.status;
    return permission == PermissionStatus.granted;
  }

  Future<bool> requestLocationPermission() async {
    final permission = await Permission.location.request();
    return permission == PermissionStatus.granted;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPosition?> getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable location services.',
        );
      }

      // Check for location permission
      bool hasPermission = await hasLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          throw Exception(
            'Location permission denied. Please grant location permission.',
          );
        }
      }

      // Get current location with timeout
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: LocationConfig.locationTimeoutSeconds),
        ),
      );

      return LocationPosition(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Future<bool> isWithinAllowedLocation() async {
    try {
      final currentLocation = await getCurrentLocation();
      if (currentLocation == null) {
        return false;
      }

      for (final zone in LocationConfig.allowedLocations) {
        if (_isWithinZone(currentLocation, zone)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking location: $e');
      return false;
    }
  }

  bool _isWithinZone(LocationPosition current, LocationZone zone) {
    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      zone.latitude,
      zone.longitude,
    );

    return distance <= zone.radius;
  }

  List<LocationZone> getAllowedLocations() {
    return LocationConfig.allowedLocations;
  }

  Future<String> getLocationStatusMessage() async {
    try {
      final currentLocation = await getCurrentLocation();
      if (currentLocation == null) {
        return 'Unable to get current location';
      }

      for (final zone in LocationConfig.allowedLocations) {
        final distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          zone.latitude,
          zone.longitude,
        );

        if (distance <= zone.radius) {
          return 'You are within ${zone.name} (${distance.toStringAsFixed(0)}m from center)';
        }
      }

      // Find nearest allowed location
      double minDistance = double.infinity;
      LocationZone? nearestZone;

      for (final zone in LocationConfig.allowedLocations) {
        final distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          zone.latitude,
          zone.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestZone = zone;
        }
      }

      if (nearestZone != null) {
        return 'You are ${minDistance.toStringAsFixed(0)}m away from ${nearestZone.name}. Please move within ${nearestZone.radius}m to login.';
      }

      return 'You are not in any allowed location';
    } catch (e) {
      return 'Error checking location: $e';
    }
  }
}

class LocationPosition {
  final double latitude;
  final double longitude;

  LocationPosition({required this.latitude, required this.longitude});
}
