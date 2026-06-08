import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/holiday_model.dart';
import '../../../services/holiday_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployeeCalendarScreen — shows holidays that apply to the logged-in
// employee's department. Department-filtered by HolidayService.
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeCalendarScreen extends StatefulWidget {
  const EmployeeCalendarScreen({super.key});

  @override
  State<EmployeeCalendarScreen> createState() => _EmployeeCalendarScreenState();
}

class _EmployeeCalendarScreenState extends State<EmployeeCalendarScreen> {
  List<HolidayModel> _holidays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  Future<void> _loadHolidays() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    final dept = provider.currentEmployee?.department ?? '';

    // Seed holidays if Firestore collection is empty
    await HolidayService.seedIfEmpty();

    final list = dept.isEmpty
        ? await HolidayService.fetchAll()
        : await HolidayService.fetchForDept(dept);
    if (mounted) setState(() { _holidays = list; _loading = false; });
  }

  // ── Group by month ────────────────────────────────────────────────────────
  Map<int, List<HolidayModel>> get _byMonth {
    final map = <int, List<HolidayModel>>{};
    for (final h in _holidays) {
      (map[h.date.month] ??= []).add(h);
    }
    return map;
  }

  // ── Next upcoming holiday ─────────────────────────────────────────────────
  HolidayModel? get _nextHoliday {
    final now = DateTime.now();
    try {
      return _holidays.firstWhere(
        (h) => h.date.isAfter(now.subtract(const Duration(days: 1))),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Days until next holiday ───────────────────────────────────────────────
  int _daysUntil(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    final dept = emp?.department ?? 'All Departments';
    final accent = provider.currentAccentColor;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.accentDefault, strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: _loadHolidays,
                color: AppColors.accentDefault,
                backgroundColor: AppColors.surface,
                child: CustomScrollView(
                  slivers: [
                    // ── Header ────────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Holiday Calendar',
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 13, color: accent),
                              const SizedBox(width: 4),
                              Text(dept,
                                  style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Text('· ${_holidays.length} holidays',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textTertiary,
                                      fontSize: 12)),
                            ]),
                          ],
                        ),
                      ),
                    ),

                    // ── Next holiday card ──────────────────────────────────
                    if (_nextHoliday != null)
                      SliverToBoxAdapter(
                        child: _NextHolidayCard(
                          holiday: _nextHoliday!,
                          daysUntil: _daysUntil(_nextHoliday!.date),
                          accent: accent,
                        ),
                      ),

                    // ── Month-by-month list ────────────────────────────────
                    if (_holidays.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.celebration_rounded,
                                  size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text('No holidays for $dept this year',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              Text('Pull to refresh',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textTertiary,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final entries = _byMonth.entries.toList();
                            final entry = entries[i];
                            return _MonthSection(
                              month: entry.key,
                              holidays: entry.value,
                              accent: accent,
                            );
                          },
                          childCount: _byMonth.length,
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Next holiday spotlight card ────────────────────────────────────────────────
class _NextHolidayCard extends StatelessWidget {
  final HolidayModel holiday;
  final int daysUntil;
  final Color accent;

  const _NextHolidayCard({
    required this.holiday,
    required this.daysUntil,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.2), accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEXT HOLIDAY',
                  style: GoogleFonts.inter(
                      color: accent.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Text(
                holiday.name,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${holiday.date.day} ${holiday.monthName} · ${holiday.dayName}',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                daysUntil == 0 ? '🎉' : '$daysUntil',
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: daysUntil == 0 ? 32 : 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (daysUntil != 0)
                Text('days left',
                    style: GoogleFonts.inter(
                        color: AppColors.textTertiary, fontSize: 11)),
              if (daysUntil == 0)
                Text('Today!',
                    style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Month section ─────────────────────────────────────────────────────────────
class _MonthSection extends StatelessWidget {
  final int month;
  final List<HolidayModel> holidays;
  final Color accent;

  const _MonthSection({
    required this.month,
    required this.holidays,
    required this.accent,
  });

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _monthNames[month],
              style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
          ...holidays.map((h) => _EmployeeHolidayTile(holiday: h)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Single holiday tile ───────────────────────────────────────────────────────
class _EmployeeHolidayTile extends StatelessWidget {
  final HolidayModel holiday;

  const _EmployeeHolidayTile({required this.holiday});

  Color get _typeColor {
    switch (holiday.type) {
      case 'optional': return AppColors.statusHalfDay;
      case 'restricted': return const Color(0xFF818CF8);
      default: return AppColors.statusPresent;
    }
  }

  bool get _isPast =>
      holiday.date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  bool get _isToday {
    final now = DateTime.now();
    return holiday.date.year == now.year &&
        holiday.date.month == now.month &&
        holiday.date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isToday
            ? _typeColor.withValues(alpha: 0.1)
            : _isPast
                ? AppColors.surfaceAlt
                : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isToday
              ? _typeColor.withValues(alpha: 0.5)
              : _isPast
                  ? AppColors.divider
                  : _typeColor.withValues(alpha: 0.2),
          width: _isToday ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        // Date badge
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isPast
                ? AppColors.surfaceAlt
                : _typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${holiday.date.day}',
                  style: GoogleFonts.inter(
                    color: _isPast ? AppColors.textTertiary : _typeColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
              Text(holiday.shortMonthName,
                  style: GoogleFonts.inter(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    holiday.name,
                    style: GoogleFonts.inter(
                      color: _isPast
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('TODAY',
                        style: GoogleFonts.inter(
                            color: AppColors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(holiday.typeLabel,
                      style: GoogleFonts.inter(
                          color: _typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(holiday.dayName,
                    style: GoogleFonts.inter(
                        color: AppColors.textTertiary, fontSize: 11)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}
