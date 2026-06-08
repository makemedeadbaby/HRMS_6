import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_model.dart';
import '../../../widgets/common/app_widgets.dart';
import '../../../models/company_model.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _filterCompany = 'All';
  String _filterDept   = 'All';
  String _filterShift = 'All';
  String _filterStatus = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().startLiveAttendanceSync();
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await context.read<AppProvider>().refreshAttendance();
    if (mounted) setState(() => _refreshing = false);
  }

  List<String> _shiftOptions(AppProvider provider) {
    const defaults = [
      'Night Shift',
      'Day Shift',
      'UK Shift',
      'UAE Shift',
      'Australian Shift',
    ];
    final fromData = provider.employees
        .map((e) => e.shiftType)
        .where((s) => s.isNotEmpty);
    return ['All', ...{...defaults, ...fromData}.toList()..sort()];
  }

  bool _matchesEmployeeFilters(EmployeeModel emp) {
    if (_filterCompany != 'All' && emp.companyName != _filterCompany) {
      return false;
    }
    if (_filterDept != 'All' && emp.department != _filterDept) return false;
    if (_filterShift != 'All' && emp.shiftType != _filterShift) return false;
    if (_searchQuery.isNotEmpty &&
        !emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
        !emp.employeeId.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }
    return true;
  }

  Widget _buildFilterChips({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    Color Function(String)? accentFor,
  }) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = selected == option;
          final accent =
              accentFor?.call(option) ?? AppColors.accent;
          final chipColor = isSelected
              ? (option == 'All' ? AppColors.accent : accent)
              : AppColors.textSecondary;
          return GestureDetector(
            onTap: () => onSelected(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? chipColor : AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? chipColor : AppColors.divider,
                ),
              ),
              child: Center(
                child: Text(
                  option,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
              'Attendance Management',
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
                Tab(text: 'LIVE STATUS'),
                Tab(text: 'MANAGE RECORDS'),
              ],
            ),
            actions: [
              // Live refresh — pulls latest check-in/out data from API
              if (_refreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                  onPressed: _refresh,
                  tooltip: 'Refresh attendance',
                ),
              IconButton(
                icon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
                onPressed: () => _selectDate(context),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildLiveStatusTab(provider),
              _buildManageRecordsTab(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveStatusTab(AppProvider provider) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final companies = ['All', ...provider.allCompanies.map((c) => c.name)];

    // Get today's attendance
    final todayAttendance = provider.allAttendanceLogs
        .where((a) => DateFormat('yyyy-MM-dd').format(a.date) == todayStr)
        .toList();

    // Build a map of employee -> today's attendance
    final Map<String, AttendanceModel?> empAttendance = {};
    for (final emp in provider.employees) {
      empAttendance[emp.id] = todayAttendance
          .where((a) => a.employeeId == emp.id)
          .firstOrNull;
    }

    final filtered =
        provider.employees.where(_matchesEmployeeFilters).toList();
    final shifts = _shiftOptions(provider);

    // Stats
    final totalEmp = filtered.length;
    int present = 0, absent = 0, onBreak = 0, checkedOut = 0;
    for (final emp in filtered) {
      final att = empAttendance[emp.id];
      if (att != null) {
        final s = att.status;
        final checkedIn = att.checkInTime != null;
        if (s == 'Present' || s == 'Late' || checkedIn) { present++; }
        else if (s == 'Absent') { absent++; }
        else if (s == 'Checked Out') { checkedOut++; }
        final breaks = att.breaks;
        if (breaks.isNotEmpty && breaks.last.endTime == null) { onBreak++; }
      }
    }

    return Column(
      children: [
        // Filters
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              AppTextField(
                controller: _searchController,
                hint: 'Search employee name or ID...',
                prefix: Icon(Icons.search),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: companies,
                selected: _filterCompany,
                onSelected: (v) => setState(() => _filterCompany = v),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: ['All', ...CompanyModel.standardDepartments],
                selected: _filterDept,
                onSelected: (v) => setState(() => _filterDept = v),
                accentFor: (_) => const Color(0xFF818CF8),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: shifts,
                selected: _filterShift,
                onSelected: (v) => setState(() => _filterShift = v),
              ),
            ],
          ),
        ),

        // Stats row
        Container(
          color: AppColors.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatPill('Total', totalEmp, AppColors.textSecondary),
              const SizedBox(width: 8),
              _StatPill('Present', present, AppColors.statusPresent),
              const SizedBox(width: 8),
              _StatPill('Absent', absent, AppColors.statusAbsent),
              const SizedBox(width: 8),
              _StatPill('Break', onBreak, AppColors.statusOnBreak),
              const SizedBox(width: 8),
              _StatPill('Out', checkedOut, AppColors.textSecondary),
            ],
          ),
        ),

        // Employee attendance list
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No employees found',
                  subtitle: 'Try adjusting your filters',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final emp = filtered[i];
                    final att = empAttendance[emp.id];
                    return _LiveAttendanceCard(
                      employee: emp,
                      attendance: att,
                      accentColor: provider.getCompanyAccent(emp.companyId),
                      onManualMark: () => _showManualMarkDialog(context, provider, emp, att),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildManageRecordsTab(AppProvider provider) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dateAttendance = provider.allAttendanceLogs
        .where((a) => DateFormat('yyyy-MM-dd').format(a.date) == dateStr)
        .toList();

    final statuses = ['All', 'Present', 'Absent', 'Half Day', 'Late', 'Leave', 'Checked Out'];
    final companies = ['All', ...provider.allCompanies.map((c) => c.name)];
    final shifts = _shiftOptions(provider);
    final filtered =
        provider.employees.where(_matchesEmployeeFilters).toList();

    return Column(
      children: [
        // Date selector
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: AppColors.accent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.divider),
                  ),
                ),
                icon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                }),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.divider),
                  ),
                ),
                icon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                }),
              ),
            ],
          ),
        ),

        // Filters
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              AppTextField(
                controller: _searchController,
                hint: 'Search employees...',
                prefix: Icon(Icons.search),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: companies,
                selected: _filterCompany,
                onSelected: (v) => setState(() => _filterCompany = v),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: ['All', ...CompanyModel.standardDepartments],
                selected: _filterDept,
                onSelected: (v) => setState(() => _filterDept = v),
                accentFor: (_) => const Color(0xFF818CF8),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(
                options: shifts,
                selected: _filterShift,
                onSelected: (v) => setState(() => _filterShift = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: statuses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final s = statuses[i];
                    final selected = _filterStatus == s;
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.statusColor(s == 'All' ? '' : s)
                              : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColors.statusColor(s == 'All' ? '' : s)
                                : AppColors.divider,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Records
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length + (_auditLogsForDate(provider, dateStr).isNotEmpty ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final auditLogs = _auditLogsForDate(provider, dateStr);
              if (i == filtered.length && auditLogs.isNotEmpty) {
                return _AuditLogSection(logs: auditLogs);
              }
              final emp = filtered[i];
              final att = dateAttendance.where((a) => a.employeeId == emp.id).firstOrNull;

              if (_filterStatus != 'All' && att?.status != _filterStatus) {
                return const SizedBox.shrink();
              }

              return _ManualMarkCard(
                employee: emp,
                attendance: att,
                accentColor: provider.getCompanyAccent(emp.companyId),
                onMark: () => _showManualMarkDialog(context, provider, emp, att),
              );
            },
          ),
        ),
      ],
    );
  }

  List<AuditLog> _auditLogsForDate(AppProvider provider, String dateStr) {
    return provider.auditLogs
        .where((a) => DateFormat('yyyy-MM-dd').format(a.changedAt) == dateStr)
        .toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showManualMarkDialog(
    BuildContext context,
    AppProvider provider,
    EmployeeModel emp,
    AttendanceModel? currentAtt,
  ) {
    String selectedStatus = currentAtt?.status ?? 'Present';
    final reasonController = TextEditingController();
    final statuses = ['Present', 'Absent', 'Half Day', 'Late', 'Leave'];

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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: provider.getCompanyAccent(emp.companyId).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          emp.name[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            color: provider.getCompanyAccent(emp.companyId),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            emp.employeeId,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Mark Attendance for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statuses.map((s) {
                    final isSelected = selectedStatus == s;
                    final color = AppColors.statusColor(s);
                    return GestureDetector(
                      onTap: () => setLocal(() => selectedStatus = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.2) : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : AppColors.divider,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          s,
                          style: GoogleFonts.inter(
                            color: isSelected ? color : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Reason for manual marking (required)',
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
                const SizedBox(height: 20),
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
                        label: 'Confirm',
                        onTap: () {
                          if (reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please provide a reason',
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: AppColors.statusAbsent,
                              ),
                            );
                            return;
                          }
                          provider.adminMarkAttendance(
                            employeeId: emp.id,
                            date: _selectedDate,
                            newStatus: selectedStatus,
                            reason: reasonController.text.trim(),
                            adminName: 'Admin',
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Attendance marked: ${emp.name} → $selectedStatus',
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
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAttendanceCard extends StatelessWidget {
  final EmployeeModel employee;
  final AttendanceModel? attendance;
  final Color accentColor;
  final VoidCallback onManualMark;

  const _LiveAttendanceCard({
    required this.employee,
    required this.attendance,
    required this.accentColor,
    required this.onManualMark,
  });

  void _showSelfieDialog(BuildContext context, String selfieUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Check-in Selfie',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: selfieUrl,
                  width: 260,
                  height: 260,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 260,
                    height: 260,
                    color: AppColors.cardBg,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 260,
                    height: 260,
                    color: AppColors.cardBg,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded,
                            color: AppColors.textSecondary, size: 48),
                        const SizedBox(height: 8),
                        Text('Image unavailable',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Employee: ${employee.name}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.inter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = attendance;
    final isOnBreak = att != null &&
        att.breaks.isNotEmpty &&
        att.breaks.last.endTime == null;

    final String displayStatus;
    if (att == null) {
      displayStatus = 'Not Checked In';
    } else if (isOnBreak) {
      displayStatus = 'On Break';
    } else if (att.checkInTime != null &&
        (att.status == 'Present' || att.status.isEmpty)) {
      displayStatus = 'Present';
    } else {
      displayStatus = att.status;
    }
    return DarkCard(
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(21),
            ),
            child: Center(
              child: Text(
                employee.name[0].toUpperCase(),
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee.department} · ${employee.employeeId}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (att?.checkInTime != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'In: ${DateFormat('hh:mm a').format(att!.checkInTime!)}${att.checkOutTime != null ? ' · Out: ${DateFormat('hh:mm a').format(att.checkOutTime!)}' : ''}',
                    style: GoogleFonts.inter(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status + mark button + selfie icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: displayStatus),
              const SizedBox(height: 6),
              // Selfie thumbnail button (shows if selfie was uploaded)
              if (att != null && att.checkInSelfieUrl.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showSelfieDialog(context, att.checkInSelfieUrl),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.statusPresent.withValues(alpha: 0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                        imageUrl: att.checkInSelfieUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: Icon(Icons.camera_alt_rounded,
                              size: 14, color: AppColors.textSecondary),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: AppColors.statusPresent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              GestureDetector(
                onTap: onManualMark,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    'Mark',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

class _ManualMarkCard extends StatelessWidget {
  final EmployeeModel employee;
  final AttendanceModel? attendance;
  final Color accentColor;
  final VoidCallback onMark;

  const _ManualMarkCard({
    required this.employee,
    required this.attendance,
    required this.accentColor,
    required this.onMark,
  });

  void _showSelfieDialog(BuildContext context, String selfieUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Check-in Selfie',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: selfieUrl,
                  width: 260,
                  height: 260,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 260,
                    height: 260,
                    color: AppColors.cardBg,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 260,
                    height: 260,
                    color: AppColors.cardBg,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded,
                            color: AppColors.textSecondary, size: 48),
                        const SizedBox(height: 8),
                        Text('Image unavailable',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Employee: ${employee.name}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.inter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = attendance;
    final status = att?.status ?? 'Not Marked';

    return DarkCard(
      child: Row(
        children: [
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: att?.isManuallyMarked == true ? AppColors.statusLate : accentColor,
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
                      employee.name,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (att?.isManuallyMarked == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusLate.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MANUAL',
                          style: GoogleFonts.inter(
                            color: AppColors.statusLate,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${employee.department} · ${employee.companyName}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (att?.markedReason.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${att!.markedReason}',
                    style: GoogleFonts.inter(
                      color: AppColors.textHint,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: status),
              const SizedBox(height: 6),
              // Selfie thumbnail — tap to view full selfie
              if (att != null && att.checkInSelfieUrl.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _showSelfieDialog(context, att.checkInSelfieUrl),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.statusPresent.withValues(alpha: 0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: CachedNetworkImage(
                        imageUrl: att.checkInSelfieUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: Icon(Icons.camera_alt_rounded,
                              size: 12, color: AppColors.textSecondary),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.camera_alt_rounded,
                          size: 12,
                          color: AppColors.statusPresent,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              GestureDetector(
                onTap: onMark,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      color: AppColors.accent,
                      fontSize: 12,
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

class _AuditLogSection extends StatelessWidget {
  final List<AuditLog> logs;

  const _AuditLogSection({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'AUDIT TRAIL',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        ...logs.map((log) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.statusLate.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, size: 14, color: AppColors.statusLate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${log.updatedBy} changed ${log.employeeName}: ${log.previousStatus} → ${log.newStatus}${log.reason.isNotEmpty ? ' (${log.reason})' : ''}',
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(log.changedAt),
                    style: GoogleFonts.inter(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
