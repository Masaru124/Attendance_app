class Attendance {
  final int id;
  final int studentId;
  final String studentName;
  final int sessionId;
  final String subject;
  final DateTime markedAt;
  final String status;
  final double? latitude;
  final double? longitude;

  Attendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.sessionId,
    required this.subject,
    required this.markedAt,
    required this.status,
    this.latitude,
    this.longitude,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      sessionId: json['session_id'],
      subject: json['subject'],
      markedAt: DateTime.parse(json['marked_at']),
      status: json['status'],
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'])
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'session_id': sessionId,
      'subject': subject,
      'marked_at': markedAt.toIso8601String(),
      'status': status,
      'latitude': latitude?.toString(),
      'longitude': longitude?.toString(),
    };
  }
}

class AttendanceStats {
  final int totalSessions;
  final int totalAttendance;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final double attendancePercentage;

  AttendanceStats({
    required this.totalSessions,
    required this.totalAttendance,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.attendancePercentage,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalSessions: json['total_sessions'] ?? 0,
      totalAttendance: json['total_attendance'] ?? 0,
      presentCount: json['present_count'] ?? 0,
      lateCount: json['late_count'] ?? 0,
      absentCount: json['absent_count'] ?? 0,
      attendancePercentage: (json['attendance_percentage'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_sessions': totalSessions,
      'total_attendance': totalAttendance,
      'present_count': presentCount,
      'late_count': lateCount,
      'absent_count': absentCount,
      'attendance_percentage': attendancePercentage,
    };
  }
}
