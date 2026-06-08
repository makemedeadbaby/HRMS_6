import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../theme/app_theme.dart';
import '../../../models/holiday_model.dart';
import '../../../models/company_model.dart';
import '../../../services/holiday_service.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// AdminHolidayScreen — admin can:
//   • View all Indian public holidays for the year
//   • Toggle each holiday on/off per department
//   • Add custom holidays (with optional dept restrictions)
//   • Delete custom holidays
// ─────────────────────────────────────────────────────────────────────────────
class AdminHolidayScreen extends StatefulWidget {
  const AdminHolidayScreen({super.key});

  @override
  State<AdminHolidayScreen> createState() => _AdminHolidayScreenState();
}

class _AdminHolidayScreenState extends State<AdminHolidayScreen>
    with SingleTickerProviderStateMixin {
  List<HolidayModel> _holidays = [];
  bool _loading = true;
  String _filterType = 'All'; // All / Public / Optional / Custom
  late TabController _tabCtrl;

  // dept selector state
  String _selectedDeptView = 'All Depts';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadHolidays();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    setState(() => _loading = true);
    // Seed if empty first
    await HolidayService.seedIfEmpty();
    final list = await HolidayService.fetchAll();
    if (mounted) setState(() { _holidays = list; _loading = false; });
  }

  // ── Filtered list based on current dept view ────────────────────────────
  List<HolidayModel> get _filtered {
    var list = List<HolidayModel>.from(_holidays);
    if (_filterType != 'All') {
      list = list.where((h) {
        if (_filterType == 'Public')   return h.type == 'public';
        if (_filterType == 'Optional') return h.type == 'optional';
        if (_filterType == 'Custom')   return !h.isNational;
        return true;
      }).toList();
    }
    if (_selectedDeptView != 'All Depts') {
      list = list.where((h) => h.appliesToDept(_selectedDeptView)).toList();
    }
    return list;
  }

  // ── Group holidays by month ──────────────────────────────────────────────
  Map<int, List<HolidayModel>> get _byMonth {
    final map = <int, List<HolidayModel>>{};
    for (final h in _filtered) {
      (map[h.date.month] ??= []).add(h);
    }
    return map;
  }

  // ── Toggle dept applicability ─────────────────────────────────────────────
  Future<void> _toggleDeptForHoliday(HolidayModel h, String dept, bool include) async {
    List<String> updated;
    if (h.applicableDepartments.isEmpty) {
      // Was ALL — restrict to all EXCEPT this dept
      updated = CompanyModel.standardDepartments
          .where((d) => d != dept)
          .toList();
    } else if (include) {
      updated = [...h.applicableDepartments, dept];
    } else {
      updated = h.applicableDepartments.where((d) => d != dept).toList();
      // If none left, means no dept gets it — keep as empty [] would mean ALL
      // so we leave the empty list = none (filter by isEmpty in viewer)
    }
    await HolidayService.updateDeptApplicability(
        holidayId: h.id, depts: updated);
    await _loadHolidays();
  }

  // ── Reset to ALL depts ────────────────────────────────────────────────────
  Future<void> _resetToAll(HolidayModel h) async {
    await HolidayService.updateDeptApplicability(holidayId: h.id, depts: []);
    await _loadHolidays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Festival Calendar',
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      Text('Indian Holidays 2025 · Customize per dept',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.accentDefault),
                    tooltip: 'Add Custom Holiday',
                    onPressed: () => _showAddHolidayDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Dept filter pills ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All Depts', ...CompanyModel.standardDepartments]
                      .map((d) {
                    final sel = _selectedDeptView == d;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDeptView = d),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF818CF8).withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF818CF8)
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(d,
                            style: GoogleFonts.inter(
                              color: sel
                                  ? const Color(0xFF818CF8)
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Tab bar ────────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: AppColors.accentDefault,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400),
                labelColor: AppColors.black,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'All Holidays'),
                  Tab(text: 'Dept Config'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Body ───────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accentDefault, strokeWidth: 2))
                  : TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _buildCalendarTab(),
                        _buildDeptConfigTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TAB 1 — Calendar view (all holidays grouped by month)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildCalendarTab() {
    final byMonth = _byMonth;
    if (byMonth.isEmpty) {
      return const Center(
        child: Text('No holidays found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: byMonth.entries.map((entry) {
        final month = entry.key;
        final holidays = entry.value;
        const monthNames = [
          '', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                monthNames[month],
                style: GoogleFonts.inter(
                    color: AppColors.accentDefault,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ),
            ...holidays.map((h) => _HolidayCard(
                  holiday: h,
                  onEdit: () => _showEditDeptDialog(context, h),
                  onDelete: h.isNational
                      ? null
                      : () => _confirmDelete(context, h),
                )),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TAB 2 — Dept config (toggle each holiday per dept)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildDeptConfigTab() {
    if (_selectedDeptView == 'All Depts') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tune_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('Select a department above\nto configure holidays',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final dept = _selectedDeptView;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF818CF8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: Color(0xFF818CF8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Toggle holidays for $dept. Checked = this dept observes the holiday.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF818CF8), fontSize: 12),
              ),
            ),
          ]),
        ),
        ..._holidays.map((h) {
          final applies = h.appliesToDept(dept);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: applies
                  ? AppColors.statusPresent.withValues(alpha: 0.05)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: applies
                    ? AppColors.statusPresent.withValues(alpha: 0.3)
                    : AppColors.divider,
              ),
            ),
            child: Row(children: [
              // Date badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: applies
                      ? AppColors.statusPresent.withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${h.date.day}',
                      style: GoogleFonts.inter(
                        color: applies
                            ? AppColors.statusPresent
                            : AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      h.shortMonthName,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.name,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${h.typeLabel} · ${h.dayName}',
                      style: GoogleFonts.inter(
                          color: AppColors.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: applies,
                onChanged: (v) => _toggleDeptForHoliday(h, dept, v),
                activeTrackColor: AppColors.statusPresent,
                inactiveThumbColor: AppColors.textTertiary,
                inactiveTrackColor: AppColors.surfaceAlt,
              ),
            ]),
          );
        }),
      ],
    );
  }

  // ── Show edit dept dialog for a single holiday ────────────────────────────
  void _showEditDeptDialog(BuildContext context, HolidayModel h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(h.name,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Text(
                '${h.date.day} ${h.monthName} 2025',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Text('Applies to departments:',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // current status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  h.applicableDepartments.isEmpty
                      ? '✅ All Departments'
                      : h.applicableDepartments.join(', '),
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton_(
                label: 'Reset to ALL departments',
                onTap: () {
                  Navigator.pop(ctx);
                  _resetToAll(h);
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add custom holiday dialog ──────────────────────────────────────────────
  void _showAddHolidayDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime? pickedDate;
    String holidayType = 'public';
    final selectedDepts = <String>{}; // empty = all

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Add Custom Holiday',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                // Name
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Holiday name',
                    hintStyle: GoogleFonts.inter(
                        color: AppColors.textTertiary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.accentDefault, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
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
                    if (d != null) setModal(() => pickedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 16, color: AppColors.accentDefault),
                      const SizedBox(width: 10),
                      Text(
                        pickedDate != null
                            ? '${pickedDate!.day}/${pickedDate!.month}/${pickedDate!.year}'
                            : 'Select date',
                        style: GoogleFonts.inter(
                          color: pickedDate != null
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // Type
                Row(children: [
                  for (final t in ['public', 'optional', 'restricted']) ...[
                    GestureDetector(
                      onTap: () => setModal(() => holidayType = t),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: holidayType == t
                              ? AppColors.accentDefault.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: holidayType == t
                                ? AppColors.accentDefault
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(t[0].toUpperCase() + t.substring(1),
                            style: GoogleFonts.inter(
                              color: holidayType == t
                                  ? AppColors.accentDefault
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: holidayType == t
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                // Dept selector (optional restriction)
                Text('Restrict to departments (leave empty for all):',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CompanyModel.standardDepartments.map((d) {
                    final sel = selectedDepts.contains(d);
                    return GestureDetector(
                      onTap: () => setModal(() {
                        if (sel) {
                          selectedDepts.remove(d);
                        } else {
                          selectedDepts.add(d);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF818CF8).withValues(alpha: 0.15)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFF818CF8)
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(d,
                            style: GoogleFonts.inter(
                              color: sel
                                  ? const Color(0xFF818CF8)
                                  : AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                PrimaryButton_(
                  label: 'ADD HOLIDAY',
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty || pickedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please fill name and date')));
                      return;
                    }
                    final newHoliday = HolidayModel(
                      id: 'custom_${_uuid.v4().substring(0, 8)}',
                      name: nameCtrl.text.trim(),
                      date: pickedDate!,
                      type: holidayType,
                      isNational: false,
                      applicableDepartments: selectedDepts.toList(),
                    );
                    await HolidayService.addHoliday(newHoliday);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadHolidays();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Holiday "${newHoliday.name}" added!',
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
    );
  }

  // ── Confirm delete ─────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, HolidayModel h) {
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
            Text('Delete "${h.name}"?',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('This holiday will be removed for all departments.',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider)),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await HolidayService.deleteHoliday(h.id);
                    await _loadHolidays();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusAbsent,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text('Delete',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Holiday card widget ────────────────────────────────────────────────────────
class _HolidayCard extends StatelessWidget {
  final HolidayModel holiday;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _HolidayCard({
    required this.holiday,
    required this.onEdit,
    this.onDelete,
  });

  Color get _typeColor {
    switch (holiday.type) {
      case 'optional': return AppColors.statusHalfDay;
      case 'restricted': return const Color(0xFF818CF8);
      default: return AppColors.statusPresent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final past = holiday.date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: past ? AppColors.surfaceAlt : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: past ? AppColors.divider : _typeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        // Date badge
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: past
                ? AppColors.surfaceAlt
                : _typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${holiday.date.day}',
                style: GoogleFonts.inter(
                  color: past ? AppColors.textTertiary : _typeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                holiday.shortMonthName,
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                holiday.name,
                style: GoogleFonts.inter(
                  color: past ? AppColors.textTertiary : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    holiday.typeLabel,
                    style: GoogleFonts.inter(
                        color: _typeColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  holiday.dayName,
                  style: GoogleFonts.inter(
                      color: AppColors.textTertiary, fontSize: 11),
                ),
                if (holiday.applicableDepartments.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.people_outline_rounded,
                      size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${holiday.applicableDepartments.length} dept(s)',
                      style: GoogleFonts.inter(
                          color: AppColors.textTertiary, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  Text('All depts',
                      style: GoogleFonts.inter(
                          color: AppColors.textTertiary, fontSize: 10)),
                ],
              ]),
            ],
          ),
        ),
        // Actions
        Row(children: [
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.tune_rounded,
                  size: 18, color: AppColors.textTertiary),
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.statusAbsent),
              ),
            ),
        ]),
      ]),
    );
  }
}

// ── Minimal primary button used locally ────────────────────────────────────────
class PrimaryButton_ extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const PrimaryButton_({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentDefault,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}
