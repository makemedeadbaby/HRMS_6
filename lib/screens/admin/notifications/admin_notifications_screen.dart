import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/common/app_widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Send notification form state
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetType = 'global';
  String _targetValue = '';
  String _priority = 'Normal';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              'Notifications',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'SEND NOTIFICATION'),
                Tab(text: 'HISTORY'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSendTab(context, provider),
              _buildHistoryTab(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSendTab(BuildContext context, AppProvider provider) {
    final targetTypes = [
      {'key': 'global', 'label': 'Global', 'icon': Icons.public},
      {'key': 'individual', 'label': 'Individual', 'icon': Icons.person},
    ];

    final priorities = ['Normal', 'Important', 'Urgent'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.notifications_active, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.isEmpty
                            ? 'Notification Title'
                            : _titleController.text,
                        style: GoogleFonts.inter(
                          color: _titleController.text.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _messageController.text.isEmpty
                            ? 'Your message will appear here...'
                            : _messageController.text,
                        style: GoogleFonts.inter(
                          color: _messageController.text.isEmpty
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title
          _SectionLabel('NOTIFICATION TITLE'),
          const SizedBox(height: 8),
          AppTextField(
            controller: _titleController,
            hint: 'e.g. Office Closure Tomorrow',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Message
          _SectionLabel('MESSAGE'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 4,
            style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Write your notification message here...',
              hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
              filled: true,
              fillColor: AppColors.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.accent),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),

          // Target type
          _SectionLabel('TARGET AUDIENCE'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: targetTypes.map((t) {
              final selected = _targetType == t['key'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _targetType = t['key'] as String;
                    _targetValue = '';
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t['icon'] as IconData,
                        color: selected ? AppColors.accent : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['label'] as String,
                        style: GoogleFonts.inter(
                          color: selected ? AppColors.accent : AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          if (_targetType == 'individual') ...[
            _SectionLabel('SELECT EMPLOYEE'),
            const SizedBox(height: 8),
            _buildTargetValueSelector(provider),
            const SizedBox(height: 16),
          ],

          // Priority
          _SectionLabel('PRIORITY'),
          const SizedBox(height: 10),
          Row(
            children: priorities.map((p) {
              final selected = _priority == p;
              final color = _priorityColor(p);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: Container(
                    margin: EdgeInsets.only(right: priorities.last == p ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.15) : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? color : AppColors.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p,
                          style: GoogleFonts.inter(
                            color: selected ? color : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Recipient count preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Recipients: ',
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  _getRecipientText(provider),
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Send button
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: _isSending ? 'Sending...' : 'Send Notification',
              onTap: _isSending ? null : () => _sendNotification(context, provider),
              icon: Icons.send_rounded,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Notifications appear in employees\' Alerts center',
              style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetValueSelector(AppProvider provider) {
    switch (_targetType) {
      case 'individual':
        return Column(
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: ListView.builder(
                itemCount: provider.employees.length,
                itemBuilder: (context, i) {
                  final emp = provider.employees[i];
                  final selected = _targetValue == emp.id;
                  return InkWell(
                    onTap: () => setState(() => _targetValue = emp.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: selected ? AppColors.accent.withValues(alpha: 0.1) : Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: provider.getCompanyAccent(emp.companyId).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                emp.name[0],
                                style: GoogleFonts.inter(
                                  color: provider.getCompanyAccent(emp.companyId),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp.name,
                                  style: GoogleFonts.inter(
                                    color: selected ? AppColors.accent : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  emp.companyName,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textHint,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle, color: AppColors.accent, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHistoryTab(AppProvider provider) {
    final notifications = provider.allNotifications;

    if (notifications.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none,
        title: 'No notifications sent',
        subtitle: 'Send your first notification using the Send tab',
      );
    }

    // Group by date
    final grouped = <String, List<NotificationModel>>{};
    for (final n in notifications) {
      final key = DateFormat('dd MMM yyyy').format(n.createdAt);
      grouped.putIfAbsent(key, () => []).add(n);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.entries.length,
      itemBuilder: (context, i) {
        final entry = grouped.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((n) => _NotificationHistoryCard(notification: n)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  String _getRecipientText(AppProvider provider) {
    switch (_targetType) {
      case 'global':
        return 'All ${provider.employees.length} employees (from joining date)';
      case 'individual':
        if (_targetValue.isEmpty) return 'Select an employee';
        final emp = provider.employees
            .where((e) => e.id == _targetValue)
            .firstOrNull;
        return emp?.name ?? 'Unknown';
      default:
        return 'Unknown';
    }
  }

  void _sendNotification(BuildContext context, AppProvider provider) async {
    if (_titleController.text.trim().isEmpty) {
      _showError(context, 'Please enter a notification title');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showError(context, 'Please enter a notification message');
      return;
    }
    if (_targetType == 'individual' && _targetValue.isEmpty) {
      _showError(context, 'Please select an employee');
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isSending = true);

    await Future.delayed(const Duration(milliseconds: 800));

    await provider.sendNotification(
      title: _titleController.text.trim(),
      message: _messageController.text.trim(),
      priority: _priority,
      targetType: _targetType,
      targetValue: _targetValue,
      createdBy: 'Admin',
    );

    setState(() {
      _isSending = false;
      _titleController.clear();
      _messageController.clear();
      _targetType = 'global';
      _targetValue = '';
      _priority = 'Normal';
    });

    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Notification sent successfully!', style: GoogleFonts.inter()),
          ],
        ),
        backgroundColor: AppColors.statusPresent,
        behavior: SnackBarBehavior.floating,
      ),
    );

    _tabController.animateTo(1);
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: AppColors.statusAbsent,
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Urgent': return AppColors.statusAbsent;
      case 'Important': return AppColors.statusHalfDay;
      default: return AppColors.textSecondary;
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _NotificationHistoryCard extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationHistoryCard({required this.notification});

  Color _priorityColor(String p) {
    switch (p) {
      case 'Urgent': return AppColors.statusAbsent;
      case 'Important': return AppColors.statusHalfDay;
      default: return AppColors.textSecondary;
    }
  }

  IconData _targetIcon(String t) {
    switch (t) {
      case 'global':
      case 'all':
        return Icons.public;
      case 'individual':
      case 'employee':
        return Icons.person;
      default:
        return Icons.send;
    }
  }

  String _targetLabel(NotificationModel n) {
    if (n.isIndividual) {
      return 'Individual';
    }
    return 'Global';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(notification.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: priorityColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (notification.priority != 'Normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notification.priority.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: priorityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _targetIcon(notification.targetType),
                  size: 13,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  _targetLabel(notification),
                  style: GoogleFonts.inter(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  notification.timeAgo,
                  style: GoogleFonts.inter(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
