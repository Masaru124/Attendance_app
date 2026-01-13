import 'package:flutter/material.dart';

enum LeaveStatus { pending, approved, rejected }

class LeaveRequest {
  final int id;
  final int studentId;
  final String studentName;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final LeaveStatus status;
  final int? reviewedBy;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    this.reviewedBy,
    this.reviewerName,
    this.reviewedAt,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? 0,
      studentName: json['student_name'] ?? 'Unknown',
      fromDate: _parseDate(json['from_date']),
      toDate: _parseDate(json['to_date']),
      reason: json['reason'] ?? '',
      status: _parseStatus(json['status']),
      reviewedBy: json['reviewed_by'],
      reviewerName: json['reviewer_name'],
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  static DateTime _parseDate(dynamic dateStr) {
    if (dateStr == null) return DateTime.now();
    if (dateStr is DateTime) return dateStr;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  static LeaveStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'APPROVED':
        return LeaveStatus.approved;
      case 'REJECTED':
        return LeaveStatus.rejected;
      default:
        return LeaveStatus.pending;
    }
  }

  String get dateRangeString {
    final format = 'dd MMM yyyy';
    final from = "${fromDate.day}/${fromDate.month}/${fromDate.year}";
    final to = "${toDate.day}/${toDate.month}/${toDate.year}";
    return "$from - $to";
  }

  String get statusString {
    switch (status) {
      case LeaveStatus.pending:
        return 'PENDING';
      case LeaveStatus.approved:
        return 'APPROVED';
      case LeaveStatus.rejected:
        return 'REJECTED';
    }
  }

  Color get statusColor {
    switch (status) {
      case LeaveStatus.pending:
        return Colors.orange;
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
    }
  }

  int get totalDays {
    return toDate.difference(fromDate).inDays + 1;
  }
}
