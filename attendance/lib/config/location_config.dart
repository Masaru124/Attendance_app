class LocationConfig {
  // Define allowed locations (latitude, longitude, radius in meters)
  static const List<LocationZone> allowedLocations = [
    LocationZone(
      name: "College Campus",
      latitude: 12.8882236,
      longitude: 77.5932829,
      radius: 500,
    ),
  ];

  static const bool enforceLocationCheck = true;
  static const bool allowAdminTeacherAnywhere = true;
  static const int locationTimeoutSeconds = 30;
}

class LocationZone {
  final String name;
  final double latitude;
  final double longitude;
  final double radius;

  const LocationZone({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}
