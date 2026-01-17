/// Model representing an attendance session
class AttendanceSession {
  final int id;
  final String sessionName;
  final String? location;
  final String createdAt;
  final bool isClosed;
  final int totalRecords;
  final String? qrImageBase64;

  AttendanceSession({
    required this.id,
    required this.sessionName,
    this.location,
    required this.createdAt,
    required this.isClosed,
    this.totalRecords = 0,
    this.qrImageBase64,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    // Handle both 'id' (from GET endpoints) and 'session_id' (from POST endpoint)
    final sessionId = json['session_id'] ?? json['id'] ?? 0;
    return AttendanceSession(
      id: sessionId,
      sessionName: json['session_name'] ?? '',
      location: json['location'],
      createdAt: json['created_at'] ?? '',
      isClosed: json['is_closed'] ?? false,
      totalRecords: json['total_records'] ?? 0,
      qrImageBase64: json['qr_image_base64'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_name': sessionName,
      'location': location,
      'created_at': createdAt,
      'is_closed': isClosed,
      'total_records': totalRecords,
      'qr_image_base64': qrImageBase64,
    };
  }

  /// Create a new session for sending to API
  factory AttendanceSession.create({
    required String sessionName,
    String? location,
  }) {
    return AttendanceSession(
      id: 0,
      sessionName: sessionName,
      location: location,
      createdAt: DateTime.now().toIso8601String(),
      isClosed: false,
      totalRecords: 0,
    );
  }

  /// Format created date for display
  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt;
    }
  }

  /// Check if session is active (not closed)
  bool get isActive => !isClosed;
}
