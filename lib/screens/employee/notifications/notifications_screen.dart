import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/common/app_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Pull fresh notifications from server every time this tab opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await context.read<AppProvider>().refreshNotifications();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return const SizedBox();

    final accent = provider.currentAccentColor;
    final notifications = provider.myNotifications;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyHeaderBar(
                      companyName: emp.companyName, accentColor: accent),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_refreshing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentDefault),
                        )
                      else
                        GestureDetector(
                          onTap: _refresh,
                          child: const Icon(Icons.refresh_rounded,
                              color: AppColors.textSecondary, size: 20),
                        ),
                      if (provider.unreadCount > 0) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: provider.markAllRead,
                          child: Text(
                            'Mark all read',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.accentDefault,
                backgroundColor: AppColors.surface,
                child: notifications.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: 'No notifications',
                            subtitle:
                                'Pull down to refresh. Notifications sent by admin appear here.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _NotificationCard(
                          notification: notifications[i],
                          employeeId: emp.id,
                          accent: accent,
                          onTap: () => provider
                              .markNotificationRead(notifications[i].id),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final String employeeId;
  final Color accent;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.employeeId,
    required this.accent,
    required this.onTap,
  });

  bool get _isRead => notification.isReadFor(employeeId);

  Color get _priorityBorderColor {
    switch (notification.priority.toLowerCase()) {
      case 'urgent':
        return AppColors.priorityUrgent;
      case 'important':
        return AppColors.priorityImportant;
      default:
        return AppColors.divider;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isRead
              ? AppColors.surface
              : AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _priorityBorderColor, width: 3),
            top: BorderSide(
                color: _isRead
                    ? AppColors.divider
                    : AppColors.divider.withValues(alpha: 0.7)),
            right: BorderSide(
                color: _isRead
                    ? AppColors.divider
                    : AppColors.divider.withValues(alpha: 0.7)),
            bottom: BorderSide(
                color: _isRead
                    ? AppColors.divider
                    : AppColors.divider.withValues(alpha: 0.7)),
          ),
        ),
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
                      fontSize: 14,
                      fontWeight: _isRead
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
                if (!_isRead)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.statusPresent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notification.message,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                PriorityBadge(priority: notification.priority),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (notification.isIndividual
                            ? AppColors.accentDefault
                            : AppColors.textTertiary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    notification.audienceLabel,
                    style: GoogleFonts.inter(
                        color: notification.isIndividual
                            ? AppColors.accentDefault
                            : AppColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  notification.timeAgo,
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
