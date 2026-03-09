import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../config/location_config.dart';

class LocationTestScreen extends ConsumerStatefulWidget {
  const LocationTestScreen({super.key});

  @override
  ConsumerState<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends ConsumerState<LocationTestScreen> {
  final LocationService _locationService = LocationService();
  String _locationStatus = 'Getting location...';
  bool _isLoading = false;
  String? _currentLocation;
  List<String> _allowedLocations = [];

  @override
  void initState() {
    super.initState();
    _loadAllowedLocations();
    _checkCurrentLocation();
  }

  void _loadAllowedLocations() {
    setState(() {
      _allowedLocations = LocationConfig.allowedLocations
          .map((zone) => '${zone.name} (${zone.latitude}, ${zone.longitude}) - ${zone.radius}m radius')
          .toList();
    });
  }

  Future<void> _checkCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _locationStatus = 'Getting current location...';
    });

    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
        });

        final isWithinAllowed = await _locationService.isWithinAllowedLocation();
        final statusMessage = await _locationService.getLocationStatusMessage();
        
        setState(() {
          _locationStatus = statusMessage;
        });
      } else {
        setState(() {
          _locationStatus = 'Failed to get location';
        });
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Test'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Location Check Enabled: ${LocationConfig.enforceLocationCheck}'),
                    Text('Admin/Teacher Bypass: ${LocationConfig.allowAdminTeacherAnywhere}'),
                    Text('Timeout: ${LocationConfig.locationTimeoutSeconds} seconds'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Allowed Locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._allowedLocations.map((location) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(location)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentLocation != null) ...[
                      Text('Current Location: $_currentLocation'),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _locationStatus,
                      style: TextStyle(
                        color: _locationStatus.contains('within') 
                            ? Colors.green 
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _checkCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Check Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
