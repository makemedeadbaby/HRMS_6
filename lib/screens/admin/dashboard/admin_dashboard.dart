import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/attendance_model.dart';
import '../../../models/employee_model.dart';
import '../../../widgets/common/app_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _filterCompany = 'All';
  String _filterShift = 'All';

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<EmployeeModel> _filteredEmployees(AppProvider provider) {
    return provider.employees.where((e) {
      if (e.status != 'Active') return false;
      if (_filterCompany != 'All' && e.companyName != _filterCompany) return false;
      if (_filterShift != 'All' && e.shiftType != _filterShift) return false;
      return true;
    }).toList();
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

  Map<String, int> _filteredStats(
    AppProvider provider,
    List<EmployeeModel> filtered,
  ) {
    final ids = filtered.map((e) => e.id).toSet();
    final logs = provider
        .getTodayAllAttendance()
        .where((a) => ids.contains(a.employeeId))
        .toList();
    return {
      'total': filtered.length,
      'present': logs
          .where((a) =>
              a.status == 'Present' ||
              a.status == 'On Break' ||
              a.checkInTime != null)
          .length,
      'absent': logs.where((a) => a.status == 'Absent').length,
      'on_break': logs.where((a) => a.status == 'On Break').length,
      'checked_out': logs.where((a) => a.status == 'Checked Out').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final filteredEmployees = _filteredEmployees(provider);
    final filteredIds = filteredEmployees.map((e) => e.id).toSet();
    final stats = _filteredStats(provider, filteredEmployees);
    final liveAttendance = provider
        .getTodayAllAttendance()
        .where((a) => filteredIds.contains(a.employeeId))
        .toList();
    final openTickets = provider.allTickets
        .where((t) =>
            t.status == 'Open' &&
            filteredEmployees.any((e) => e.id == t.employeeId))
        .length;
    final companies = provider.companies
        .where((c) =>
            _filterCompany == 'All' || c.name == _filterCompany)
        .toList();
    final now = DateTime.now();
    final companyOptions = ['All', ...provider.companies.map((c) => c.name)];
    final shiftOptions = _shiftOptions(provider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Admin Dashboard',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      DateFormat('d MMM, yyyy').format(now),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'COMPANY',
                options: companyOptions,
                selected: _filterCompany,
                onSelected: (v) => setState(() => _filterCompany = v),
                accentFor: (option) {
                  if (option == 'All') return AppColors.white;
                  return provider.getCompanyAccentByName(option);
                },
              ),
              const SizedBox(height: 10),
              _FilterSection(
                label: 'SHIFT',
                options: shiftOptions,
                selected: _filterShift,
                onSelected: (v) => setState(() => _filterShift = v),
              ),
              if (_filterCompany != 'All' || _filterShift != 'All') ...[
                const SizedBox(height: 8),
                Text(
                  'Showing ${filteredEmployees.length} employees'
                  '${_filterCompany != 'All' ? ' · $_filterCompany' : ''}'
                  '${_filterShift != 'All' ? ' · $_filterShift' : ''}',
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SectionHeader(title: 'TODAY\'S OVERVIEW'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.1,
                children: [
                  StatCard(
                    label: 'Total',
                    value: '${stats['total']}',
                    accentColor: AppColors.accentDefault,
                    icon: Icons.people_rounded,
                  ),
                  StatCard(
                    label: 'Present',
                    value: '${stats['present']}',
                    accentColor: AppColors.statusPresent,
                    icon: Icons.check_circle_rounded,
                  ),
                  StatCard(
                    label: 'Absent',
                    value: '${stats['absent']}',
                    accentColor: AppColors.statusAbsent,
                    icon: Icons.cancel_rounded,
                  ),
                  StatCard(
                    label: 'On Break',
                    value: '${stats['on_break']}',
                    accentColor: AppColors.statusOnBreak,
                    icon: Icons.coffee_rounded,
                  ),
                  StatCard(
                    label: 'Checked Out',
                    value: '${stats['checked_out']}',
                    accentColor: AppColors.statusCheckedOut,
                    icon: Icons.logout_rounded,
                  ),
                  StatCard(
                    label: 'Open Tickets',
                    value: '$openTickets',
                    accentColor: AppColors.statusLate,
                    icon: Icons.confirmation_number_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(title: 'COMPANY OVERVIEW'),
              const SizedBox(height: 12),
              ...companies.map((company) {
                final companyEmps = filteredEmployees
                    .where((e) => e.companyId == company.id)
                    .length;
                final companyPresent = liveAttendance
                    .where((a) =>
                        a.companyId == company.id &&
                        (a.status == 'Present' || a.status == 'On Break'))
                    .length;
                Color accent;
                try {
                  final hex = company.accentColorHex.replaceAll('#', '');
                  accent = Color(int.parse('FF$hex', radix: 16));
                } catch (_) {
                  accent = AppColors.companyAccent(company.name);
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: accent, width: 3),
                      top: const BorderSide(color: AppColors.divider),
                      right: const BorderSide(color: AppColors.divider),
                      bottom: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              company.name,
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$companyEmps employees',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CompanyStatPill(
                          '$companyPresent Present',
                          AppColors.statusPresent),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'LIVE ATTENDANCE',
                action: 'See all',
              ),
              const SizedBox(height: 12),
              if (liveAttendance.isEmpty)
                EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: filteredEmployees.isEmpty
                      ? 'No employees match filters'
                      : 'No attendance data yet',
                  subtitle: filteredEmployees.isEmpty
                      ? 'Try selecting a different company or shift.'
                      : 'Attendance records will appear here as employees check in.',
                )
              else
                ...liveAttendance.take(5).map((att) {
                  final emp = filteredEmployees
                      .where((e) => e.id == att.employeeId)
                      .firstOrNull;
                  return _LiveAttendanceRow(att: att, emp: emp);
                }),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color Function(String option)? accentFor;

  const _FilterSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.accentFor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final option = options[i];
              final isSelected = selected == option;
              final accent = accentFor?.call(option) ?? AppColors.accentDefault;
              final chipColor = isSelected
                  ? (option == 'All' ? AppColors.white : accent)
                  : AppColors.textSecondary;
              return GestureDetector(
                onTap: () => onSelected(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chipColor.withValues(alpha: 0.15)
                        : AppColors.surface,
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: chipColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CompanyStatPill extends StatelessWidget {
  final String label;
  final Color color;

  const _CompanyStatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LiveAttendanceRow extends StatelessWidget {
  final AttendanceModel att;
  final EmployeeModel? emp;

  const _LiveAttendanceRow({required this.att, this.emp});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.statusColor(att.status);
    final shiftLabel = emp?.shiftType;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                att.employeeName.isNotEmpty ? att.employeeName[0] : '?',
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
                  att.employeeName,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  shiftLabel != null && shiftLabel.isNotEmpty
                      ? '${att.companyName} · $shiftLabel'
                      : '${att.companyName} · ${att.department}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: att.status, small: true),
              if (att.checkInTime != null)
                Text(
                  DateFormat('hh:mm a').format(att.checkInTime!),
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
