class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String priority;
  final String targetType;
  final String targetValue;
  final String createdBy;
  final DateTime createdAt;
  final String attachmentUrl;
  bool isRead;
  DateTime? readAt;
  final List<String> readByEmployeeIds;
  final List<String> recipientEmployeeIds;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.targetType,
    required this.targetValue,
    required this.createdBy,
    required this.createdAt,
    this.attachmentUrl = '',
    this.isRead = false,
    this.readAt,
    List<String>? readByEmployeeIds,
    List<String>? recipientEmployeeIds,
  })  : readByEmployeeIds = readByEmployeeIds ?? [],
        recipientEmployeeIds = recipientEmployeeIds ?? [];

  bool get isGlobal =>
      targetType == 'global' || targetType == 'all';

  bool get isIndividual =>
      targetType == 'individual' || targetType == 'employee';

  String get audienceLabel => isIndividual ? 'Individual' : 'Global';

  bool isReadFor(String employeeId) {
    if (isIndividual) return isRead;
    return readByEmployeeIds.contains(employeeId);
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      priority: map['priority'] ?? 'Normal',
      targetType: map['target_type'] ?? 'all',
      targetValue: map['target_value'] ?? '',
      createdBy: map['created_by'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      attachmentUrl: map['attachment_url'] ?? '',
      isRead: map['is_read'] ?? false,
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at']) : null,
      readByEmployeeIds: List<String>.from(
        map['read_by_employee_ids'] ?? const [],
      ),
      recipientEmployeeIds: List<String>.from(
        map['recipient_employee_ids'] ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'message': message,
    'priority': priority,
    'target_type': targetType,
    'target_value': targetValue,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'attachment_url': attachmentUrl,
    'is_read': isRead,
    'read_at': readAt?.toIso8601String(),
    'read_by_employee_ids': readByEmployeeIds,
    'recipient_employee_ids': recipientEmployeeIds,
  };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
