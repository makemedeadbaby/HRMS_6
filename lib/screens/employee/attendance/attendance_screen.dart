import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/attendance_model.dart';
import '../../../widgets/common/app_widgets.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Color _dotColor(String? status) {
    if (status == null) return AppColors.textTertiary;
    switch (status) {
      case 'Present': return AppColors.statusPresent;
      case 'Absent': return AppColors.statusAbsent;
      case 'Half Day': return AppColors.statusHalfDay;
      case 'Late': return AppColors.statusLate;
      case 'Checked Out': return AppColors.statusCheckedOut;
      default: return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return const SizedBox();

    final accent = provider.currentAccentColor;
    final logs = provider.getEmployeeAttendance(emp.id);
    final stats = provider.getEmployeeMonthlyStats(
      emp.id,
      _focusedDay.month,
      _focusedDay.year,
    );

    // Build event map for calendar
    final Map<DateTime, List<AttendanceModel>> events = {};
    for (final log in logs) {
      final key = DateTime(log.date.year, log.date.month, log.date.day);
      events[key] = [log];
    }

    AttendanceModel? selectedLog;
    if (_selectedDay != null) {
      final key = DateTime(
          _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      selectedLog = events[key]?.firstOrNull;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyHeaderBar(companyName: emp.companyName, accentColor: accent),
                  const SizedBox(height: 16),
                  Text(
                    'Attendance',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Monthly Stats Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MiniStat('Present', '${stats['present']}', AppColors.statusPresent),
                        const SizedBox(width: 10),
                        _MiniStat('Absent', '${stats['absent']}', AppColors.statusAbsent),
                        const SizedBox(width: 10),
                        _MiniStat('Half Day', '${stats['half_day']}', AppColors.statusHalfDay),
                        const SizedBox(width: 10),
                        _MiniStat('Late', '${stats['late']}', AppColors.statusLate),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tabs
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
                      tabs: const [
                        Tab(text: 'Calendar'),
                        Tab(text: 'List'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Calendar Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TableCalendar(
                          firstDay: DateTime(2024, 1, 1),
                          lastDay: DateTime(2027, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                          },
                          onPageChanged: (focused) {
                            setState(() => _focusedDay = focused);
                          },
                          eventLoader: (day) {
                            final key = DateTime(day.year, day.month, day.day);
                            return events[key] ?? [];
                          },
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            defaultTextStyle: GoogleFonts.inter(
                                color: AppColors.textPrimary, fontSize: 13),
                            weekendTextStyle: GoogleFonts.inter(
                                color: AppColors.textSecondary, fontSize: 13),
                            selectedDecoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: GoogleFonts.inter(
                                color: AppColors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            todayDecoration: BoxDecoration(
                              border: Border.all(color: accent, width: 1.5),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: GoogleFonts.inter(
                                color: accent, fontSize: 13),
                            markerDecoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            leftChevronIcon: const Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.textSecondary),
                            rightChevronIcon: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary),
                            headerPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            weekendStyle: GoogleFonts.inter(
                                color: AppColors.textTertiary, fontSize: 12),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isEmpty) return null;
                              final att = events.first as AttendanceModel;
                              return Positioned(
                                bottom: 2,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _dotColor(att.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Selected Day Detail
                        if (selectedLog != null)
                          _AttendanceDetailCard(log: selectedLog, accent: accent)
                        else if (_selectedDay != null)
                          DarkCard(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No record for ${DateFormat('d MMMM').format(_selectedDay!)}',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // List Tab
                  ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _AttendanceListItem(
                      log: logs[i],
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDetailCard extends StatelessWidget {
  final AttendanceModel log;
  final Color accent;

  const _AttendanceDetailCard({required this.log, required this.accent});

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      borderColor: AppColors.statusColor(log.status).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('d MMMM yyyy').format(log.date),
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              StatusBadge(status: log.status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DetailItem(
                  'Check In',
                  log.checkInTime != null
                      ? DateFormat('hh:mm a').format(log.checkInTime!)
                      : '—',
                ),
              ),
              Expanded(
                child: _DetailItem(
                  'Check Out',
                  log.checkOutTime != null
                      ? DateFormat('hh:mm a').format(log.checkOutTime!)
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DetailItem('Working', log.workingHoursText),
              ),
              Expanded(
                child: _DetailItem('Break', log.breakTimeText),
              ),
            ],
          ),
          if (log.isManuallyMarked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusHalfDay.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.statusHalfDay.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded,
                      color: AppColors.statusHalfDay, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Updated by ${log.markedBy}',
                          style: GoogleFonts.inter(
                            color: AppColors.statusHalfDay,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (log.markedReason.isNotEmpty)
                          Text(
                            log.markedReason,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AttendanceListItem extends StatelessWidget {
  final AttendanceModel log;
  final Color accent;

  const _AttendanceListItem({required this.log, required this.accent});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.statusColor(log.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
          top: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(log.date),
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(log.date).toUpperCase(),
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.checkInTime != null
                          ? DateFormat('hh:mm a').format(log.checkInTime!)
                          : 'No Check-in',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (log.checkOutTime != null) ...[
                      Text(' → ',
                          style: GoogleFonts.inter(
                              color: AppColors.textTertiary, fontSize: 12)),
                      Text(
                        DateFormat('hh:mm a').format(log.checkOutTime!),
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.workingHoursText} worked · ${log.breakTimeText} break',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(status: log.status, small: true),
              if (log.isManuallyMarked)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded,
                          size: 10, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('Admin',
                          style: GoogleFonts.inter(
                              color: AppColors.textTertiary, fontSize: 9)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
