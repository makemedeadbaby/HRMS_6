import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/company_model.dart';
import '../../../widgets/common/app_widgets.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final companies = provider.allCompanies;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              'Companies',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${companies.length} Active',
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddCompanySheet(context, provider),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: Text(
              'Add Company',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
          body: companies.isEmpty
              ? const EmptyState(
                  icon: Icons.business_outlined,
                  title: 'No companies yet',
                  subtitle: 'Add your first company to get started',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: companies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final company = companies[i];
                    return _CompanyCard(
                      company: company,
                      employeeCount: provider.employees
                          .where((e) => e.companyId == company.id)
                          .length,
                      onEdit: () => _showEditCompanySheet(context, provider, company),
                      onToggle: () => provider.toggleCompanyStatus(company.id),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showAddCompanySheet(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    final addressController = TextEditingController();
    final websiteController = TextEditingController();
    final colorController = TextEditingController(text: 'F59E0B');
    final branchController = TextEditingController();
    final departmentController = TextEditingController();
    final List<String> branches = [];
    final List<String> departments = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add New Company',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'New companies will appear in the employee app automatically',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),

                _FormLabel('COMPANY NAME *'),
                const SizedBox(height: 6),
                AppTextField(
                  controller: nameController,
                  hint: 'e.g. Khush Lifestyle Pvt. Ltd.',
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('SHORT NAME *'),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: shortNameController,
                            hint: 'e.g. KHUSH',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('ACCENT COLOR (HEX)'),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: colorController,
                            hint: 'F59E0B',
                            prefix: Icon(Icons.color_lens_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _FormLabel('ADDRESS'),
                const SizedBox(height: 6),
                AppTextField(
                  controller: addressController,
                  hint: 'Company address',
                ),
                const SizedBox(height: 14),

                _FormLabel('WEBSITE'),
                const SizedBox(height: 6),
                AppTextField(
                  controller: websiteController,
                  hint: 'https://example.com',
                  prefix: Icon(Icons.link),
                ),
                const SizedBox(height: 14),

                // Branches
                _FormLabel('BRANCHES'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: branchController,
                        hint: 'Branch name',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.add, color: AppColors.accent),
                      onPressed: () {
                        if (branchController.text.trim().isNotEmpty) {
                          setLocal(() {
                            branches.add(branchController.text.trim());
                            branchController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: branches.map((b) => _TagChip(
                      label: b,
                      onRemove: () => setLocal(() => branches.remove(b)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 14),

                // Departments
                _FormLabel('DEPARTMENTS'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: departmentController,
                        hint: 'Department name',
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.add, color: AppColors.accent),
                      onPressed: () {
                        if (departmentController.text.trim().isNotEmpty) {
                          setLocal(() {
                            departments.add(departmentController.text.trim());
                            departmentController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (departments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: departments.map((d) => _TagChip(
                      label: d,
                      onRemove: () => setLocal(() => departments.remove(d)),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // Color preview
                _ColorPreview(hexColor: colorController.text),
                const SizedBox(height: 24),

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
                        label: 'Add Company',
                        onTap: () {
                          if (nameController.text.trim().isEmpty ||
                              shortNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Company name and short name are required',
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: AppColors.statusAbsent,
                              ),
                            );
                            return;
                          }

                          final company = CompanyModel(
                            id: 'comp_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameController.text.trim(),
                            shortName: shortNameController.text.trim().toUpperCase(),
                            accentColorHex: colorController.text.trim().replaceAll('#', ''),
                            address: addressController.text.trim(),
                            branches: branches.isNotEmpty ? branches : ['Head Office'],
                            departments: departments.isNotEmpty
                                ? departments
                                : ['General', 'HR', 'Operations'],
                            isActive: true,
                            createdAt: DateTime.now(),
                          );

                          provider.addCompany(company);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${company.name} added successfully!',
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

  void _showEditCompanySheet(
    BuildContext context,
    AppProvider provider,
    CompanyModel company,
  ) {
    final nameController = TextEditingController(text: company.name);
    final shortNameController = TextEditingController(text: company.shortName);
    final addressController = TextEditingController(text: company.address);
    final colorController = TextEditingController(text: company.accentColorHex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: provider.getCompanyAccent(company.id).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          company.shortName[0],
                          style: GoogleFonts.inter(
                            color: provider.getCompanyAccent(company.id),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Company',
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          company.shortName,
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _FormLabel('COMPANY NAME'),
                const SizedBox(height: 6),
                AppTextField(controller: nameController, hint: 'Company name'),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('SHORT NAME'),
                          const SizedBox(height: 6),
                          AppTextField(controller: shortNameController, hint: 'Short name'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FormLabel('ACCENT COLOR'),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: colorController,
                            hint: 'HEX color',
                            onChanged: (_) => setLocal(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _FormLabel('ADDRESS'),
                const SizedBox(height: 6),
                AppTextField(controller: addressController, hint: 'Company address'),
                const SizedBox(height: 16),

                _ColorPreview(hexColor: colorController.text),
                const SizedBox(height: 24),

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
                        label: 'Save Changes',
                        onTap: () {
                          final updated = company.copyWith(
                            name: nameController.text.trim(),
                            shortName: shortNameController.text.trim().toUpperCase(),
                            accentColorHex: colorController.text.trim().replaceAll('#', ''),
                            address: addressController.text.trim(),
                          );
                          provider.updateCompany(updated);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Company updated!',
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

class _CompanyCard extends StatelessWidget {
  final CompanyModel company;
  final int employeeCount;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _CompanyCard({
    required this.company,
    required this.employeeCount,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final accent = provider.getCompanyAccent(company.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.12),
                  AppColors.cardBg,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      company.shortName.length > 2
                          ? company.shortName.substring(0, 2)
                          : company.shortName,
                      style: GoogleFonts.inter(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              company.name,
                              style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: company.isActive
                                  ? AppColors.statusPresent
                                  : AppColors.statusAbsent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        company.shortName,
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _CompanyStat(
                  icon: Icons.people_outline,
                  value: '$employeeCount',
                  label: 'Employees',
                  color: accent,
                ),
                const SizedBox(width: 16),
                _CompanyStat(
                  icon: Icons.location_city,
                  value: '${company.branches.length}',
                  label: 'Branches',
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                _CompanyStat(
                  icon: Icons.category_outlined,
                  value: '${company.departments.length}',
                  label: 'Depts',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Address
          if (company.address.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      company.address,
                      style: GoogleFonts.inter(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Branches/departments preview
          if (company.branches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...company.branches.take(3).map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      b,
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  )),
                  if (company.branches.length > 3)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${company.branches.length - 3} more',
                        style: GoogleFonts.inter(
                          color: AppColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Divider
          Divider(color: AppColors.divider, height: 1),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Accent color swatch
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${company.accentColorHex.toUpperCase()}',
                      style: GoogleFonts.inter(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (!provider.isBuiltInCompany(company.id))
                  TextButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                      company.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 15,
                    ),
                    label: Text(
                      company.isActive ? 'Deactivate' : 'Activate',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: company.isActive
                          ? AppColors.statusAbsent
                          : AppColors.statusPresent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _CompanyStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textHint,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ColorPreview extends StatelessWidget {
  final String hexColor;

  const _ColorPreview({required this.hexColor});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.accent;
    try {
      final cleaned = hexColor.replaceAll('#', '').trim();
      if (cleaned.length == 6) {
        color = Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brand Accent Preview',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '#${hexColor.replaceAll('#', '').toUpperCase()}',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 80,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                'SAMPLE',
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _TagChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

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
