DateTime _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    if (value.length == 10) return DateTime.parse(value);
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

class AttendanceModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String companyId;
  final String companyName;
  final String department;
  final DateTime date;
  DateTime? checkInTime;
  DateTime? checkOutTime;
  String status;
  String checkInSelfieUrl;
  double? checkInLat;
  double? checkInLng;
  int totalBreakMinutes;
  bool isManuallyMarked;
  String markedBy;
  String markedReason;
  DateTime? markedAt;
  String previousStatus;
  List<BreakLog> breaks;

  AttendanceModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.companyId,
    required this.companyName,
    required this.department,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.checkInSelfieUrl = '',
    this.checkInLat,
    this.checkInLng,
    this.totalBreakMinutes = 0,
    this.isManuallyMarked = false,
    this.markedBy = '',
    this.markedReason = '',
    this.markedAt,
    this.previousStatus = '',
    List<BreakLog>? breaks,
  }) : breaks = breaks ?? [];

  int get totalWorkingMinutes {
    if (checkInTime == null || checkOutTime == null) return 0;
    final diff = checkOutTime!.difference(checkInTime!).inMinutes;
    return (diff - totalBreakMinutes).clamp(0, 9999);
  }

  String get workingHoursText {
    final mins = totalWorkingMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get breakTimeText {
    final h = totalBreakMinutes ~/ 60;
    final m = totalBreakMinutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      companyId: map['company_id'] ?? '',
      companyName: map['company_name'] ?? '',
      department: map['department'] ?? '',
      date: _parseDate(map['date']),
      checkInTime: map['check_in_time'] != null ? DateTime.tryParse(map['check_in_time']) : null,
      checkOutTime: map['check_out_time'] != null ? DateTime.tryParse(map['check_out_time']) : null,
      status: map['status'] ?? 'Absent',
      checkInSelfieUrl: map['check_in_selfie_url'] ?? '',
      checkInLat: (map['check_in_lat'] as num?)?.toDouble(),
      checkInLng: (map['check_in_lng'] as num?)?.toDouble(),
      totalBreakMinutes: map['total_break_minutes'] ?? 0,
      isManuallyMarked: map['is_manually_marked'] ?? false,
      markedBy: map['marked_by'] ?? '',
      markedReason: map['marked_reason'] ?? '',
      markedAt: map['marked_at'] != null ? DateTime.tryParse(map['marked_at']) : null,
      previousStatus: map['previous_status'] ?? '',
      breaks: (map['breaks'] as List<dynamic>?)
              ?.map((b) => BreakLog.fromMap(b as Map<String, dynamic>))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'company_id': companyId,
      'company_name': companyName,
      'department': department,
      'date': date.toIso8601String().substring(0, 10),
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status,
      'check_in_selfie_url': checkInSelfieUrl,
      'check_in_lat': checkInLat,
      'check_in_lng': checkInLng,
      'total_break_minutes': totalBreakMinutes,
      'is_manually_marked': isManuallyMarked,
      'marked_by': markedBy,
      'marked_reason': markedReason,
      'marked_at': markedAt?.toIso8601String(),
      'previous_status': previousStatus,
      'breaks': breaks.map((b) => b.toMap()).toList(),
    };
  }
}

class BreakLog {
  final String id;
  DateTime startTime;
  DateTime? endTime;

  BreakLog({required this.id, required this.startTime, this.endTime});

  int get durationMinutes {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMinutes;
  }

  factory BreakLog.fromMap(Map<String, dynamic> map) {
    return BreakLog(
      id: map['id'] ?? '',
      startTime: DateTime.tryParse(map['start_time'] ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
  };
}

class AuditLog {
  final String id;
  final String attendanceId;
  final String employeeId;
  final String employeeName;
  final String previousStatus;
  final String newStatus;
  final String updatedBy;
  final DateTime updatedAt;
  final String reason;

  // Alias for consistent API
  DateTime get changedAt => updatedAt;

  AuditLog({
    required this.id,
    required this.attendanceId,
    required this.employeeId,
    this.employeeName = '',
    required this.previousStatus,
    required this.newStatus,
    required this.updatedBy,
    required this.updatedAt,
    required this.reason,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] ?? '',
      attendanceId: map['attendance_id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      previousStatus: map['previous_status'] ?? '',
      newStatus: map['new_status'] ?? '',
      updatedBy: map['updated_by'] ?? '',
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      reason: map['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'attendance_id': attendanceId,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'previous_status': previousStatus,
    'new_status': newStatus,
    'updated_by': updatedBy,
    'updated_at': updatedAt.toIso8601String(),
    'reason': reason,
  };
}
