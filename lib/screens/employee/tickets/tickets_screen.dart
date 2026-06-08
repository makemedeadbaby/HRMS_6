import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/ticket_model.dart';
import '../../../widgets/common/app_widgets.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    // Auto-fetch latest tickets from API when screen opens
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
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return const SizedBox();

    final accent = provider.currentAccentColor;
    final tickets = provider.myTickets;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
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
                          'Tickets',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Refresh button — syncs latest replies/status from server
                      if (_refreshing)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _refresh,
                          child: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AppColors.black,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: const [Tab(text: 'My Tickets'), Tab(text: 'Raise New')],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // My Tickets tab — pull-to-refresh to sync latest status/replies
                  RefreshIndicator(
                    onRefresh: _refresh,
                    color: accent,
                    child: tickets.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.confirmation_number_outlined,
                                title: 'No tickets yet',
                                subtitle:
                                    'Raise a ticket if you have any issue and we will resolve it.',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            itemCount: tickets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _TicketCard(ticket: tickets[i], accent: accent),
                          ),
                  ),
                  _RaiseTicketForm(accent: accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;
  final Color accent;

  const _TicketCard({required this.ticket, required this.accent});

  Color get _statusColor {
    switch (ticket.status) {
      case 'Open': return AppColors.statusOnBreak;
      case 'In Progress': return AppColors.accentLearningSaint;
      case 'Resolved': return AppColors.statusPresent;
      case 'Closed': return AppColors.statusCheckedOut;
      case 'Rejected': return AppColors.statusAbsent;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.id,
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              PriorityBadge(priority: ticket.priority),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.status,
                  style: GoogleFonts.inter(
                      color: _statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.description,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket.category,
                  style: GoogleFonts.inter(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM, hh:mm a').format(ticket.createdAt),
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          if (ticket.adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.reply_rounded,
                    color: AppColors.statusPresent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.repliedBy,
                        style: GoogleFonts.inter(
                            color: AppColors.statusPresent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        ticket.adminReply,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RaiseTicketForm extends StatefulWidget {
  final Color accent;
  const _RaiseTicketForm({required this.accent});

  @override
  State<_RaiseTicketForm> createState() => _RaiseTicketFormState();
}

class _RaiseTicketFormState extends State<_RaiseTicketForm> {
  final _formKey = GlobalKey<FormState>();
  String _category = TicketModel.categories.first;
  String _priority = 'Normal';
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    context.read<AppProvider>().raiseTicket(
          category: _category,
          subject: _subjectCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          priority: _priority,
        );

    setState(() => _submitting = false);
    _subjectCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _category = TicketModel.categories.first;
      _priority = 'Normal';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ticket raised successfully!', style: GoogleFonts.inter()),
        backgroundColor: AppColors.statusPresent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category
            _fieldLabel('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TicketModel.categories.map((cat) {
                final selected = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.accent.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? widget.accent
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(
                        color: selected
                            ? widget.accent
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _fieldLabel('Subject'),
            const SizedBox(height: 8),
            AppTextField(
              hint: 'Brief title of your issue',
              controller: _subjectCtrl,
              validator: (v) => v == null || v.isEmpty ? 'Enter subject' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Description'),
            const SizedBox(height: 8),
            AppTextField(
              hint: 'Describe your issue in detail...',
              controller: _descCtrl,
              maxLines: 4,
              validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
            ),
            const SizedBox(height: 20),
            _fieldLabel('Priority'),
            const SizedBox(height: 8),
            Row(
              children: ['Normal', 'Important', 'Urgent'].map((p) {
                final selected = _priority == p;
                Color color;
                switch (p) {
                  case 'Urgent': color = AppColors.priorityUrgent; break;
                  case 'Important': color = AppColors.priorityImportant; break;
                  default: color = AppColors.textSecondary;
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? color : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        p,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: selected ? color : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'SUBMIT TICKET',
              isLoading: _submitting,
              onTap: _submit,
              bg: widget.accent,
              fg: AppColors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      );
}
