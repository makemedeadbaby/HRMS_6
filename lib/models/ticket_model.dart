class TicketModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String companyId;
  final String companyName;
  final String category;
  final String subject;
  final String description;
  final String attachmentUrl;
  String status;
  final String priority;
  final DateTime createdAt;
  DateTime? resolvedAt;
  String adminReply;
  String repliedBy;
  List<Map<String, String>> messages;

  // Computed getters
  String get ticketId => 'TKT-${id.substring(id.length > 8 ? id.length - 8 : 0).toUpperCase()}';

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 30}mo ago';
  }

  TicketModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.companyId,
    required this.companyName,
    required this.category,
    required this.subject,
    required this.description,
    this.attachmentUrl = '',
    required this.status,
    required this.priority,
    required this.createdAt,
    this.resolvedAt,
    this.adminReply = '',
    this.repliedBy = '',
    List<Map<String, String>>? messages,
  }) : messages = messages ?? [];

  static const List<String> categories = [
    'Attendance Issue',
    'Salary Issue',
    'Leave Issue',
    'ID Card Issue',
    'System / App Issue',
    'HR Query',
    'Manager Concern',
    'Other',
  ];

  static const List<String> statuses = [
    'Open',
    'In Progress',
    'Resolved',
    'Rejected',
    'Closed',
  ];

  factory TicketModel.fromMap(Map<String, dynamic> map) {
    return TicketModel(
      id: map['id'] ?? '',
      employeeId: map['employee_id'] ?? '',
      employeeName: map['employee_name'] ?? '',
      companyId: map['company_id'] ?? '',
      companyName: map['company_name'] ?? '',
      category: map['category'] ?? '',
      subject: map['subject'] ?? '',
      description: map['description'] ?? '',
      attachmentUrl: map['attachment_url'] ?? '',
      status: map['status'] ?? 'Open',
      priority: map['priority'] ?? 'Normal',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      resolvedAt: map['resolved_at'] != null ? DateTime.tryParse(map['resolved_at']) : null,
      adminReply: map['admin_reply'] ?? '',
      repliedBy: map['replied_by'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'employee_id': employeeId,
    'employee_name': employeeName,
    'company_id': companyId,
    'company_name': companyName,
    'category': category,
    'subject': subject,
    'description': description,
    'attachment_url': attachmentUrl,
    'status': status,
    'priority': priority,
    'created_at': createdAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'admin_reply': adminReply,
    'replied_by': repliedBy,
  };
}
