import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/ticket_model.dart';
import '../../../widgets/common/app_widgets.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  String _filterStatus = 'All';
  String _filterPriority = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _refreshing = false;

  final _statuses = ['All', 'Open', 'In Progress', 'Resolved', 'Closed', 'Escalated'];
  final _priorities = ['All', 'Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    // Pull latest tickets from API every time admin opens this tab
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await context.read<AppProvider>().refreshTickets();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        var tickets = provider.allTickets;

        if (_filterStatus != 'All') {
          tickets = tickets.where((t) => t.status == _filterStatus).toList();
        }
        if (_filterPriority != 'All') {
          tickets = tickets.where((t) => t.priority == _filterPriority).toList();
        }
        if (_searchQuery.isNotEmpty) {
          tickets = tickets.where((t) =>
              t.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.employeeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.ticketId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }

        // Stats
        final open = provider.allTickets.where((t) => t.status == 'Open').length;
        final inProgress = provider.allTickets.where((t) => t.status == 'In Progress').length;
        final critical = provider.allTickets.where((t) => t.priority == 'Critical').length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              'Support Tickets',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              // Refresh button
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                  onPressed: _refresh,
                  tooltip: 'Refresh tickets',
                ),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusAbsent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$open Open',
                    style: GoogleFonts.inter(
                      color: AppColors.statusAbsent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Stats bar
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    _TicketStatCard(
                      label: 'Total',
                      count: provider.allTickets.length,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    _TicketStatCard(
                      label: 'Open',
                      count: open,
                      color: AppColors.statusAbsent,
                    ),
                    const SizedBox(width: 8),
                    _TicketStatCard(
                      label: 'In Progress',
                      count: inProgress,
                      color: AppColors.statusOnBreak,
                    ),
                    const SizedBox(width: 8),
                    _TicketStatCard(
                      label: 'Critical',
                      count: critical,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),

              // Search
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: AppTextField(
                  controller: _searchController,
                  hint: 'Search tickets, employees...',
                  prefix: Icon(Icons.search),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              // Status filters
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final s = _statuses[i];
                      final selected = _filterStatus == s;
                      return GestureDetector(
                        onTap: () => setState(() => _filterStatus = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: selected ? AppColors.accent : AppColors.divider,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              s,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.black : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Priority filters
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _priorities.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final p = _priorities[i];
                      final selected = _filterPriority == p;
                      final color = _priorityColor(p);
                      return GestureDetector(
                        onTap: () => setState(() => _filterPriority = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? color : AppColors.divider.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              p,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: selected ? color : AppColors.textHint,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Tickets list
              Expanded(
                child: tickets.isEmpty
                    ? const EmptyState(
                        icon: Icons.support_agent_outlined,
                        title: 'No tickets found',
                        subtitle: 'Try adjusting your filters',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          return _AdminTicketCard(
                            ticket: tickets[i],
                            accentColor:
                                provider.getCompanyAccentByName(tickets[i].companyName),
                            onReply: () => _showReplyDialog(context, provider, tickets[i]),
                            onStatusChange: () =>
                                _showStatusDialog(context, provider, tickets[i]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Critical': return const Color(0xFFEF4444);
      case 'High': return AppColors.statusOnBreak;
      case 'Medium': return AppColors.statusHalfDay;
      case 'Low': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  void _showReplyDialog(BuildContext context, AppProvider provider, TicketModel ticket) {
    final replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reply to Ticket',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              // Existing messages
              if (ticket.messages.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      children: ticket.messages.map((msg) {
                        final isAdmin = msg['sender'] == 'admin';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? AppColors.accent.withValues(alpha: 0.1)
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAdmin
                                  ? AppColors.accent.withValues(alpha: 0.3)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isAdmin ? 'Admin' : msg['sender'] ?? 'Employee',
                                    style: GoogleFonts.inter(
                                      color: isAdmin ? AppColors.accent : AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    msg['time'] ?? '',
                                    style: GoogleFonts.inter(
                                      color: AppColors.textHint,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['message'] ?? '',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: replyController,
                maxLines: 3,
                style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write your reply...',
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
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedActionButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Send Reply',
                      onTap: () {
                        if (replyController.text.trim().isEmpty) return;
                        provider.adminReplyTicket(
                          ticket.id,
                          replyController.text.trim(),
                          'Admin',
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reply sent!', style: GoogleFonts.inter()),
                            backgroundColor: AppColors.statusPresent,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, AppProvider provider, TicketModel ticket) {
    final statuses = ['Open', 'In Progress', 'Resolved', 'Closed', 'Escalated'];
    String selected = ticket.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Ticket Status',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ticket.ticketId,
                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                ...statuses.map((s) {
                  final isSelected = selected == s;
                  return GestureDetector(
                    onTap: () => setLocal(() => selected = s),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _statusColor(s),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            s,
                            style: GoogleFonts.inter(
                              color: isSelected ? AppColors.accent : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedActionButton(
                        label: 'Cancel',
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Update',
                        onTap: () {
                          provider.updateTicketStatus(ticket.id, selected);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Status updated to $selected',
                                style: GoogleFonts.inter(),
                              ),
                              backgroundColor: AppColors.statusPresent,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Open': return AppColors.statusAbsent;
      case 'In Progress': return AppColors.statusOnBreak;
      case 'Resolved': return AppColors.statusPresent;
      case 'Closed': return AppColors.textSecondary;
      case 'Escalated': return AppColors.statusLate;
      default: return AppColors.textSecondary;
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TicketStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TicketStatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTicketCard extends StatelessWidget {
  final TicketModel ticket;
  final Color accentColor;
  final VoidCallback onReply;
  final VoidCallback onStatusChange;

  const _AdminTicketCard({
    required this.ticket,
    required this.accentColor,
    required this.onReply,
    required this.onStatusChange,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'Open': return AppColors.statusAbsent;
      case 'In Progress': return AppColors.statusOnBreak;
      case 'Resolved': return AppColors.statusPresent;
      case 'Closed': return AppColors.textSecondary;
      case 'Escalated': return AppColors.statusLate;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);

    return DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 3,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          ticket.ticketId,
                          style: GoogleFonts.inter(
                            color: AppColors.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        PriorityBadge(priority: ticket.priority),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticket.subject,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Employee & company info
          Row(
            children: [
              Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                ticket.employeeName,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.business_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                ticket.companyName,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                ticket.category,
                style: GoogleFonts.inter(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Description preview
          Text(
            ticket.description,
            style: GoogleFonts.inter(
              color: AppColors.textHint,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Footer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.status,
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (ticket.messages.isNotEmpty) ...[
                Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  '${ticket.messages.length}',
                  style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 11),
                ),
              ],
              const Spacer(),
              Text(
                ticket.timeAgo,
                style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 11),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onStatusChange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onReply,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Reply',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
