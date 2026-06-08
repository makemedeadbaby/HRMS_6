import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/company_model.dart';
import '../../../models/employee_model.dart';
import '../../../widgets/common/app_widgets.dart';

const _uuid = Uuid();



class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  String _searchQuery = '';
  String _filterCompany = 'All';
  String _filterDept = 'All';
  String _filterShift = 'All';

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

  List<String> get _deptOptions =>
      ['All', ...CompanyModel.standardDepartments];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final employees = provider.employees.where((e) {
      final matchSearch = _searchQuery.isEmpty ||
          e.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.employeeCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.loginId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchCompany = _filterCompany == 'All' || e.companyName == _filterCompany;
      final matchDept    = _filterDept == 'All' || e.department == _filterDept;
      final matchShift = _filterShift == 'All' || e.shiftType == _filterShift;
      return matchSearch && matchCompany && matchDept && matchShift;
    }).toList();

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
                  Text(
                    'Employees',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search
                  AppTextField(
                    hint: 'Search by name, ID, login ID...',
                    prefix: const Icon(Icons.search_rounded,
                        color: AppColors.textTertiary, size: 18),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        ...provider.companies.map((c) => c.name),
                      ].map((company) {
                        final selected = _filterCompany == company;
                        Color accent = AppColors.textSecondary;
                        if (company != 'All') {
                          final comp = provider.companies
                              .where((c) => c.name == company)
                              .firstOrNull;
                          if (comp != null) {
                            accent = provider.getCompanyAccent(comp.id);
                          }
                        }
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _filterCompany = company),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (company == 'All'
                                      ? AppColors.white
                                      : accent).withValues(alpha: 0.15)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? (company == 'All'
                                        ? AppColors.white
                                        : accent)
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              company,
                              style: GoogleFonts.inter(
                                color: selected
                                    ? (company == 'All'
                                        ? AppColors.white
                                        : accent)
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
                  ),
                  const SizedBox(height: 10),
                  // ── Department filter ────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _deptOptions.map((dept) {
                        final selected = _filterDept == dept;
                        const color = Color(0xFF818CF8); // indigo accent
                        return GestureDetector(
                          onTap: () => setState(() => _filterDept = dept),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.15)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? color : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              dept,
                              style: GoogleFonts.inter(
                                color: selected
                                    ? color
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
                  ),
                  const SizedBox(height: 10),
                  // ── Shift filter ──────────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _shiftOptions(provider).map((shift) {
                        final selected = _filterShift == shift;
                        return GestureDetector(
                          onTap: () => setState(() => _filterShift = shift),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accentDefault
                                      .withValues(alpha: 0.15)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accentDefault
                                    : AppColors.divider,
                              ),
                            ),
                            child: Text(
                              shift,
                              style: GoogleFonts.inter(
                                color: selected
                                    ? AppColors.accentDefault
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
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${employees.length} employee${employees.length != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: employees.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No employees found',
                      subtitle: 'Try adjusting your search or filters.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _EmployeeCard(
                        employee: employees[i],
                        accent: provider
                            .getCompanyAccent(employees[i].companyId),
                        onResetPassword: () =>
                            _showResetPasswordDialog(context, employees[i]),
                        onEdit: () =>
                            _showEditDialog(context, employees[i]),
                        onDelete: () =>
                            _showDeleteConfirmDialog(context, employees[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Admin Password Reset button
          FloatingActionButton.small(
            heroTag: 'admin_pass',
            onPressed: () => _showAdminPasswordResetDialog(context),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textSecondary,
            tooltip: 'Reset Admin Password',
            child: const Icon(Icons.admin_panel_settings_rounded, size: 18),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_emp',
            onPressed: () => _showAddEmployeeDialog(context),
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.black,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text('Add Employee',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, EmployeeModel emp) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset Password — ${emp.fullName}',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            AppTextField(hint: 'New password', controller: ctrl, obscure: true),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Reset Password',
              onTap: () {
                if (ctrl.text.isNotEmpty) {
                  context.read<AppProvider>().resetEmployeePassword(emp.id, ctrl.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset for ${emp.fullName}',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.statusPresent,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, EmployeeModel emp) {
    // Simplified edit - just show info
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee Details',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            InfoRow(label: 'Employee ID', value: emp.employeeCode),
            Divider(color: AppColors.divider),
            InfoRow(label: 'Login ID', value: emp.loginId),
            Divider(color: AppColors.divider),
            InfoRow(label: 'Company', value: emp.companyName),
            Divider(color: AppColors.divider),
            InfoRow(label: 'Department', value: emp.department),
            Divider(color: AppColors.divider),
            InfoRow(label: 'Shift', value: '${emp.shiftStartTime} – ${emp.shiftEndTime}'),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, EmployeeModel emp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.statusAbsent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_remove_rounded,
                  color: AppColors.statusAbsent, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove Employee?',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to remove ${emp.fullName} from the system? This action cannot be undone.',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${emp.employeeCode} · ${emp.loginId} · ${emp.companyName}',
                style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AppProvider>().deleteEmployee(emp.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${emp.fullName} has been removed.',
                            style: GoogleFonts.inter()),
                        backgroundColor: AppColors.statusAbsent,
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusAbsent,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Remove',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAdminPasswordResetDialog(BuildContext context) {
    String selectedAccount = 'admin';
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accentDefault.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: AppColors.accentDefault, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Reset Admin Password',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              // Account selector
              Text('Select Account',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => selectedAccount = 'admin'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedAccount == 'admin'
                              ? AppColors.accentDefault.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedAccount == 'admin'
                                ? AppColors.accentDefault
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text('admin',
                                style: GoogleFonts.inter(
                                    color: selectedAccount == 'admin'
                                        ? AppColors.accentDefault
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text('Admin',
                                style: GoogleFonts.inter(
                                    color: AppColors.textTertiary,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => selectedAccount = 'superadmin'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedAccount == 'superadmin'
                              ? AppColors.accentDefault.withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedAccount == 'superadmin'
                                ? AppColors.accentDefault
                                : AppColors.divider,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text('superadmin',
                                style: GoogleFonts.inter(
                                    color: selectedAccount == 'superadmin'
                                        ? AppColors.accentDefault
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text('Super Admin',
                                style: GoogleFonts.inter(
                                    color: AppColors.textTertiary,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                  hint: 'New Password',
                  controller: passCtrl,
                  obscure: true),
              const SizedBox(height: 10),
              AppTextField(
                  hint: 'Confirm New Password',
                  controller: confirmCtrl,
                  obscure: true),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'UPDATE PASSWORD',
                onTap: () async {
                  if (passCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Please fill all fields')));
                    return;
                  }
                  if (passCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Passwords do not match')));
                    return;
                  }
                  if (passCtrl.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Password must be at least 6 characters')));
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  final account = selectedAccount;
                  await context.read<AppProvider>().resetAdminPassword(
                    loginId: account,
                    newPassword: passCtrl.text.trim(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Password updated for $account',
                        style: GoogleFonts.inter()),
                    backgroundColor: AppColors.statusPresent,
                  ));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _companyDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final items = options.isNotEmpty ? options : [value];
    final current = items.contains(value) ? value : items.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
          items: items
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Helper: format TimeOfDay to "hh:mm AM/PM"
  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl        = TextEditingController();
    final empIdCtrl       = TextEditingController(); // custom employee ID
    final emailCtrl       = TextEditingController();
    final mobileCtrl      = TextEditingController();
    final loginCtrl       = TextEditingController();
    final passCtrl        = TextEditingController();
    final designationCtrl = TextEditingController();
    final managerCtrl     = TextEditingController(); // reporting manager
    String selectedCompany = '';
    String selectedDept    = CompanyModel.standardDepartments.first; // 'US Dept'
    String selectedBranch  = 'Noida';
    // Shift state
    String shiftName  = 'Day Shift';
    TimeOfDay shiftStart = const TimeOfDay(hour: 9,  minute: 30);
    TimeOfDay shiftEnd   = const TimeOfDay(hour: 18, minute: 30);
    // DOB state
    DateTime? selectedDob;

    final provider = context.read<AppProvider>();

    CompanyModel? initialCompany;
    if (_filterCompany != 'All') {
      initialCompany = provider.companies
          .where((c) => c.name == _filterCompany)
          .firstOrNull;
    }
    initialCompany ??= provider.companies.firstOrNull;
    if (initialCompany != null) {
      selectedCompany = initialCompany.id;
      selectedDept = CompanyModel.standardDepartments.first;
      if (initialCompany.branches.isNotEmpty) {
        selectedBranch = initialCompany.branches.first;
      }
    }

    void applyCompanySelection(String companyId, StateSetter setModal) {
      final company =
          provider.companies.where((c) => c.id == companyId).firstOrNull;
      if (company == null) return;
      setModal(() {
        selectedCompany = companyId;
        selectedDept = CompanyModel.standardDepartments.first;
        selectedBranch =
            company.branches.isNotEmpty ? company.branches.first : 'Noida';
      });
    }

    // Pre-fill shift times when name changes
    void applyShiftPreset(String name, StateSetter setModal) {
      const presets = {
        'Night Shift':      {'h1': 20, 'm1': 30, 'h2': 5,  'm2': 30},
        'Day Shift':        {'h1': 9,  'm1': 30, 'h2': 18, 'm2': 30},
        'UK Shift':         {'h1': 13, 'm1': 30, 'h2': 22, 'm2': 30},
        'UAE Shift':        {'h1': 12, 'm1': 0,  'h2': 21, 'm2': 0 },
        'Australian Shift': {'h1': 4,  'm1': 30, 'h2': 13, 'm2': 30},
      };
      final p = presets[name];
      if (p != null) {
        setModal(() {
          shiftStart = TimeOfDay(hour: p['h1']!, minute: p['m1']!);
          shiftEnd   = TimeOfDay(hour: p['h2']!, minute: p['m2']!);
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // handle bar
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('Add New Employee',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),

                  // ── Basic info ──────────────────────────────────────────
                  AppTextField(hint: 'Full Name *', controller: nameCtrl,
                      validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AppTextField(
                        hint: 'Employee ID (optional)',
                        controller: empIdCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: AppTextField(
                        hint: 'Mobile *', controller: mobileCtrl,
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 12),
                  AppTextField(hint: 'Email', controller: emailCtrl),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: AppTextField(
                        hint: 'Designation', controller: designationCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: AppTextField(
                        hint: 'Reporting Manager *',
                        controller: managerCtrl,
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 12),

                  // ── Company (all 4 group companies selectable) ───────────
                  Text('Company *',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.companies.map((c) {
                      final selected = selectedCompany == c.id;
                      final accent = provider.getCompanyAccent(c.id);
                      return GestureDetector(
                        onTap: () => applyCompanySelection(c.id, setModal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withValues(alpha: 0.18)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? accent : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              color: selected ? accent : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _companyDropdown(
                        label: 'Department',
                        value: CompanyModel.standardDepartments
                                .contains(selectedDept)
                            ? selectedDept
                            : CompanyModel.standardDepartments.first,
                        options: CompanyModel.standardDepartments,
                        onChanged: (v) =>
                            setModal(() => selectedDept = v ?? selectedDept),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _companyDropdown(
                        label: 'Branch',
                        value: selectedBranch,
                        options: provider.companies
                                .where((c) => c.id == selectedCompany)
                                .firstOrNull
                                ?.branches ??
                            ['Noida'],
                        onChanged: (v) =>
                            setModal(() => selectedBranch = v ?? selectedBranch),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Credentials ─────────────────────────────────────────
                  Row(children: [
                    Expanded(child: AppTextField(hint: 'Login ID *', controller: loginCtrl,
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                    const SizedBox(width: 10),
                    Expanded(child: AppTextField(hint: 'Password *', controller: passCtrl,
                        obscure: true,
                        validator: (v) => v!.isEmpty ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 12),

                  // ── Shift name dropdown ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: shiftName,
                        dropdownColor: AppColors.surface,
                        isExpanded: true,
                        items: ['Night Shift','Day Shift','UK Shift','UAE Shift','Australian Shift']
                            .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s,
                                  style: GoogleFonts.inter(
                                      color: AppColors.textPrimary, fontSize: 13)),
                            )).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModal(() => shiftName = v);
                          applyShiftPreset(v, setModal);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Shift time pickers ───────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: shiftStart,
                            builder: (c, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.white,
                                  surface: AppColors.surface,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setModal(() => shiftStart = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(children: [
                            const Icon(Icons.access_time_rounded,
                                size: 16, color: AppColors.accentDefault),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textTertiary, fontSize: 10)),
                                Text(_fmtTime(shiftStart),
                                    style: GoogleFonts.inter(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: shiftEnd,
                            builder: (c, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.white,
                                  surface: AppColors.surface,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setModal(() => shiftEnd = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(children: [
                            const Icon(Icons.access_time_filled_rounded,
                                size: 16, color: AppColors.statusHalfDay),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Time',
                                    style: GoogleFonts.inter(
                                        color: AppColors.textTertiary, fontSize: 10)),
                                Text(_fmtTime(shiftEnd),
                                    style: GoogleFonts.inter(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  // shift summary chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentDefault.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: AppColors.accentDefault),
                      const SizedBox(width: 6),
                      Text('$shiftName: ${_fmtTime(shiftStart)} – ${_fmtTime(shiftEnd)}',
                          style: GoogleFonts.inter(
                              color: AppColors.accentDefault,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Date of Birth ────────────────────────────────────────
                  Text('Date of Birth (for birthday feature)',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDob ?? DateTime(now.year - 25, 1, 1),
                        firstDate: DateTime(1950),
                        lastDate: DateTime(now.year - 16),
                        builder: (c, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.accentDefault,
                              surface: AppColors.surface,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setModal(() => selectedDob = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedDob != null
                              ? const Color(0xFFEC4899)
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.cake_rounded,
                            size: 16,
                            color: selectedDob != null
                                ? const Color(0xFFEC4899)
                                : AppColors.textTertiary),
                        const SizedBox(width: 10),
                        Text(
                          selectedDob != null
                              ? '${selectedDob!.day} / ${selectedDob!.month} / ${selectedDob!.year}'
                              : 'Tap to select date of birth (optional)',
                          style: GoogleFonts.inter(
                            color: selectedDob != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                        if (selectedDob != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setModal(() => selectedDob = null),
                            child: const Icon(Icons.clear_rounded,
                                size: 16, color: AppColors.textTertiary),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Create button ───────────────────────────────────────
                  PrimaryButton(
                    label: 'CREATE EMPLOYEE',
                    onTap: () async {
                      if (!formKey.currentState!.validate()) return;
                      final company = provider.companies
                          .where((c) => c.id == selectedCompany)
                          .firstOrNull;
                      if (company == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a company')));
                        return;
                      }
                      // Use custom employee ID if provided, else auto-generate
                      final empCode = empIdCtrl.text.trim().isNotEmpty
                          ? empIdCtrl.text.trim()
                          : 'EMP-${1000 + provider.employees.length + 1}';
                      await provider.addEmployee(EmployeeModel(
                        id: _uuid.v4(),
                        employeeCode: empCode,
                        fullName: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        mobile: mobileCtrl.text.trim(),
                        companyId: selectedCompany,
                        companyName: company.name,
                        department: selectedDept,
                        designation: designationCtrl.text.trim().isEmpty
                            ? 'Executive'
                            : designationCtrl.text.trim(),
                        shiftType: shiftName,
                        shiftStartTime: _fmtTime(shiftStart),
                        shiftEndTime: _fmtTime(shiftEnd),
                        reportingManager: managerCtrl.text.trim(),
                        branch: selectedBranch,
                        loginId: loginCtrl.text.trim(),
                        passwordHash: passCtrl.text.trim(),
                        status: 'Active',
                        joiningDate: DateTime.now(),
                        accountCreatedAt: DateTime.now(),
                        dateOfBirth: selectedDob,
                      ));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Employee created successfully!',
                              style: GoogleFonts.inter()),
                          backgroundColor: AppColors.statusPresent,
                        ));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final Color accent;
  final VoidCallback onResetPassword;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.accent,
    required this.onResetPassword,
    required this.onEdit,
    required this.onDelete,
  });

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
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    employee.fullName[0].toUpperCase(),
                    style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fullName,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text('${employee.employeeCode} · ${employee.loginId}',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: employee.status == 'Active'
                      ? AppColors.statusPresent.withValues(alpha: 0.1)
                      : AppColors.statusAbsent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  employee.status,
                  style: GoogleFonts.inter(
                    color: employee.status == 'Active'
                        ? AppColors.statusPresent
                        : AppColors.statusAbsent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Tag(employee.companyName, accent),
              const SizedBox(width: 6),
              _Tag(employee.department, AppColors.textTertiary),
              const SizedBox(width: 6),
              _Tag(employee.branch, AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Details',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onResetPassword,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.statusHalfDay.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_reset_rounded,
                            size: 14,
                            color: AppColors.statusHalfDay),
                        const SizedBox(width: 4),
                        Text('Reset Pass',
                            style: GoogleFonts.inter(
                                color: AppColors.statusHalfDay,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: AppColors.statusAbsent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppColors.statusAbsent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            color: color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
