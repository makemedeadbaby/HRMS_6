class EmployeeModel {
  final String id;
  final String employeeCode;
  final String fullName;
  final String email;
  final String mobile;
  final String emergencyContact;
  final String companyId;
  final String companyName;
  final String department;
  final String designation;
  final String shiftType;
  final String shiftStartTime;
  final String shiftEndTime;
  final String reportingManager;
  final String branch;
  final String loginId;
  final String passwordHash;
  final String photoUrl;
  final String status;
  final DateTime joiningDate;
  final DateTime? accountCreatedAt;
  final String role;
  final bool deviceBound;
  final String boundDeviceId;
  final String fcmToken;

  EmployeeModel({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    required this.mobile,
    this.emergencyContact = '',
    required this.companyId,
    required this.companyName,
    required this.department,
    required this.designation,
    required this.shiftType,
    required this.shiftStartTime,
    required this.shiftEndTime,
    required this.reportingManager,
    required this.branch,
    required this.loginId,
    required this.passwordHash,
    this.photoUrl = '',
    required this.status,
    required this.joiningDate,
    this.accountCreatedAt,
    this.role = 'employee',
    this.deviceBound = false,
    this.boundDeviceId = '',
    this.fcmToken = '',
  });

  // Alias for fullName - used throughout UI
  String get name => fullName;

  // Employee display ID
  String get employeeId => employeeCode;

  /// When this account was created in the system (used for notification targeting).
  DateTime get accountStartDate => accountCreatedAt ?? joiningDate;

  String get tenureText {
    final now = DateTime.now();
    final diff = now.difference(joiningDate);
    final months = (diff.inDays / 30).floor();
    final days = diff.inDays % 30;
    if (months == 0) return '$days days';
    if (days == 0) return '$months months';
    return '$months months $days days';
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
      id: map['id'] ?? '',
      employeeCode: map['employee_code'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? '',
      emergencyContact: map['emergency_contact'] ?? '',
      companyId: map['company_id'] ?? '',
      companyName: map['company_name'] ?? '',
      department: map['department'] ?? '',
      designation: map['designation'] ?? '',
      shiftType: map['shift_type'] ?? 'Day Shift',
      shiftStartTime: map['shift_start_time'] ?? '09:00 AM',
      shiftEndTime: map['shift_end_time'] ?? '06:00 PM',
      reportingManager: map['reporting_manager'] ?? '',
      branch: map['branch'] ?? 'Noida',
      loginId: map['login_id'] ?? '',
      passwordHash: map['password_hash'] ?? '',
      photoUrl: map['photo_url'] ?? '',
      status: map['status'] ?? 'Active',
      joiningDate: map['joining_date'] != null
          ? DateTime.tryParse(map['joining_date']) ?? DateTime.now()
          : DateTime.now(),
      accountCreatedAt: map['account_created_at'] != null
          ? DateTime.tryParse(map['account_created_at'])
          : null,
      role: map['role'] ?? 'employee',
      deviceBound: map['device_bound'] ?? false,
      boundDeviceId: map['bound_device_id'] ?? '',
      fcmToken: map['fcm_token'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_code': employeeCode,
      'full_name': fullName,
      'email': email,
      'mobile': mobile,
      'emergency_contact': emergencyContact,
      'company_id': companyId,
      'company_name': companyName,
      'department': department,
      'designation': designation,
      'shift_type': shiftType,
      'shift_start_time': shiftStartTime,
      'shift_end_time': shiftEndTime,
      'reporting_manager': reportingManager,
      'branch': branch,
      'login_id': loginId,
      'password_hash': passwordHash,
      'photo_url': photoUrl,
      'status': status,
      'joining_date': joiningDate.toIso8601String(),
      if (accountCreatedAt != null)
        'account_created_at': accountCreatedAt!.toIso8601String(),
      'role': role,
      'device_bound': deviceBound,
      'bound_device_id': boundDeviceId,
      'fcm_token': fcmToken,
    };
  }

  EmployeeModel copyWith({
    String? status,
    String? photoUrl,
    String? passwordHash,
    String? department,
    String? designation,
    String? shiftType,
    String? shiftStartTime,
    String? shiftEndTime,
    String? companyId,
    String? companyName,
    String? branch,
    String? reportingManager,
    String? fcmToken,
  }) {
    return EmployeeModel(
      id: id,
      employeeCode: employeeCode,
      fullName: fullName,
      email: email,
      mobile: mobile,
      emergencyContact: emergencyContact,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      shiftType: shiftType ?? this.shiftType,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftEndTime: shiftEndTime ?? this.shiftEndTime,
      reportingManager: reportingManager ?? this.reportingManager,
      branch: branch ?? this.branch,
      loginId: loginId,
      passwordHash: passwordHash ?? this.passwordHash,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      joiningDate: joiningDate,
      accountCreatedAt: accountCreatedAt,
      role: role,
      deviceBound: deviceBound,
      boundDeviceId: boundDeviceId,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
