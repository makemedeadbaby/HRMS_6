import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/employee_model.dart';
import '../../../widgets/common/app_widgets.dart';
import 'checkin_screen.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  late Stream<DateTime> _timeStream;
  bool _birthdayBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    ).asBroadcastStream();
  }

  Future<void> _handleCheckIn(AppProvider provider) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CheckInScreen()),
    );
    if (result == true && mounted) setState(() {});
  }

  void _showBreakConfirm(AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              provider.isOnBreak ? 'End Break?' : 'Start Break?',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              provider.isOnBreak
                  ? 'Your break time will be recorded and status will return to Active.'
                  : 'Status will change to On Break. Duration will be tracked.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (provider.isOnBreak) {
                        provider.endBreak();
                      } else {
                        provider.startBreak();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.isOnBreak
                          ? AppColors.statusPresent
                          : AppColors.statusOnBreak,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(provider.isOnBreak ? 'End Break' : 'Start Break'),
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

  void _showCheckOutConfirm(AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 36),
            const SizedBox(height: 12),
            Text(
              'Check Out?',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your working hours will be calculated and status will be marked as Checked Out.',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  provider.checkOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Checked out successfully. Have a great day!',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusCheckedOut,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirm Check Out',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;

    // Safety guard — show spinner if provider not ready
    if (!provider.isInitialized || emp == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.accentDefault,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final accent = provider.currentAccentColor;
    final att = provider.todayAttendance;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: StreamBuilder<DateTime>(
          stream: _timeStream,
          builder: (context, snap) {
            final t = snap.data ?? DateTime.now();
            return _buildBody(context, provider, emp, att, accent, now, t);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    dynamic emp,
    dynamic att,
    Color accent,
    DateTime now,
    DateTime t,
  ) {
    // Compute elapsed time display
    final checkInTime = att?.checkInTime as DateTime?;
    final isActivelyWorking = checkInTime != null && !provider.isCheckedOut;

    String clockLine1;
    String clockLine2;
    Color clockColor;

    if (isActivelyWorking) {
      final elapsed = t.difference(checkInTime);
      final h = elapsed.inHours;
      final m = elapsed.inMinutes % 60;
      final s = elapsed.inSeconds % 60;
      clockLine1 = '${h}h ${m.toString().padLeft(2, '0')}m';
      clockLine2 = '${s.toString().padLeft(2, '0')}s  elapsed';
      clockColor = AppColors.statusPresent;
    } else {
      clockLine1 = DateFormat('hh:mm').format(t);
      clockLine2 = DateFormat('ss').format(t);
      clockColor = AppColors.textPrimary;
    }

    // Live working hours
    String workingHoursValue = att?.workingHoursText ?? '—';
    if (att != null && checkInTime != null && !provider.isCheckedOut) {
      final elapsed = t.difference(checkInTime);
      final breakMins = (att.totalBreakMinutes as int?) ?? 0;
      final liveMins = (elapsed.inMinutes - breakMins).clamp(0, 9999);
      final h = liveMins ~/ 60;
      final m = liveMins % 60;
      workingHoursValue = h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ── Company Header ──────────────────────────────────────────────
          CompanyHeaderBar(companyName: emp.companyName, accentColor: accent),
          const SizedBox(height: 12),

          // ── Birthday Banner ─────────────────────────────────────────────
          if (!_birthdayBannerDismissed)
            _BirthdayBanner(
              birthdays: provider.todaysBirthdays,
              onDismiss: () => setState(() => _birthdayBannerDismissed = true),
            ),

          const SizedBox(height: 8),

          // ── Employee Row ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      color: accent, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.fullName,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text('${emp.designation} · ${emp.branch}',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              StatusBadge(status: provider.currentStatus),
            ],
          ),
          const SizedBox(height: 24),

          // ── Main Action Card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clock / Timer
                Column(
                  children: [
                    Text(
                      clockLine1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: clockColor,
                        fontSize: isActivelyWorking ? 42 : 48,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      clockLine2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppColors.textTertiary,
                        fontSize: isActivelyWorking ? 15 : 20,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (isActivelyWorking) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Working since ${DateFormat('hh:mm a').format(checkInTime)}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(now),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // ── Action Buttons ────────────────────────────────────────
                if (!provider.isCheckedIn) ...[
                  // Not checked in yet — show CHECK IN button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleCheckIn(provider),
                      icon: const Icon(Icons.fingerprint_rounded, size: 20),
                      label: Text('CHECK IN',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else if (provider.isCheckedOut) ...[
                  // Checked out — show done state
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.statusCheckedOut, size: 18),
                        const SizedBox(width: 8),
                        Text('Checked Out for today',
                            style: GoogleFonts.inter(
                              color: AppColors.statusCheckedOut,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ] else ...[
                  // Checked in, active — show Break + Check Out buttons
                  // Live break timer if on break
                  if (provider.isOnBreak)
                    StreamBuilder<Duration>(
                      stream: provider.breakElapsedStream,
                      builder: (ctx, snap) {
                        final elapsed = snap.data ?? provider.currentBreakElapsed;
                        final mins = elapsed.inMinutes;
                        final secs = elapsed.inSeconds % 60;
                        final isOver30 = mins >= 30;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isOver30
                                ? AppColors.statusAbsent.withValues(alpha: 0.1)
                                : AppColors.statusOnBreak.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOver30
                                  ? AppColors.statusAbsent.withValues(alpha: 0.4)
                                  : AppColors.statusOnBreak.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                size: 14,
                                color: isOver30
                                    ? AppColors.statusAbsent
                                    : AppColors.statusOnBreak,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Break: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                                style: GoogleFonts.inter(
                                  color: isOver30
                                      ? AppColors.statusAbsent
                                      : AppColors.statusOnBreak,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isOver30) ...[
                                const SizedBox(width: 6),
                                Text('⚠️ Over limit',
                                    style: GoogleFonts.inter(
                                      color: AppColors.statusAbsent,
                                      fontSize: 11,
                                    )),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: provider.isOnBreak ? 'END BREAK' : 'START BREAK',
                          icon: provider.isOnBreak
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          borderColor: provider.isOnBreak
                              ? AppColors.statusPresent
                              : AppColors.statusOnBreak,
                          textColor: provider.isOnBreak
                              ? AppColors.statusPresent
                              : AppColors.statusOnBreak,
                          onTap: () => _showBreakConfirm(provider),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionBtn(
                          label: 'CHECK OUT',
                          icon: Icons.logout_rounded,
                          borderColor: AppColors.statusCheckedOut,
                          textColor: AppColors.statusCheckedOut,
                          onTap: () => _showCheckOutConfirm(provider),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Today's Stats ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Working Hours',
                  value: workingHoursValue,
                  accentColor: accent,
                  icon: Icons.access_time_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Break Time',
                  value: att?.breakTimeText ?? '—',
                  accentColor: AppColors.statusOnBreak,
                  icon: Icons.coffee_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Check-in / Check-out times ────────────────────────────────
          if (att != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TimeInfo(
                      label: 'Check In',
                      time: att.checkInTime != null
                          ? DateFormat('hh:mm a').format(att.checkInTime!)
                          : '—',
                      color: AppColors.statusPresent,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  Expanded(
                    child: _TimeInfo(
                      label: 'Check Out',
                      time: att.checkOutTime != null
                          ? DateFormat('hh:mm a').format(att.checkOutTime!)
                          : '—',
                      color: AppColors.statusCheckedOut,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  Expanded(
                    child: _TimeInfo(
                      label: 'Breaks',
                      time: '${att.breaks.length}',
                      color: AppColors.statusOnBreak,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Shift Info ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.shiftType,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          )),
                      Text('${emp.shiftStartTime} – ${emp.shiftEndTime}',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(emp.department,
                      style: GoogleFonts.inter(
                        color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Birthday Banner ───────────────────────────────────────────────────────────
class _BirthdayBanner extends StatelessWidget {
  final List<EmployeeModel> birthdays;
  final VoidCallback onDismiss;

  const _BirthdayBanner({
    required this.birthdays,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (birthdays.isEmpty) return const SizedBox.shrink();

    // Build display names list
    final names = birthdays.take(3).map((e) => e.fullName.split(' ').first).toList();
    final extraCount = birthdays.length - names.length;
    String displayNames = names.join(', ');
    if (extraCount > 0) displayNames += ' +$extraCount more';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cake emoji icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎂', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  birthdays.length == 1
                      ? '🎉 Happy Birthday!'
                      : '🎉 Birthdays Today!',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayNames,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  birthdays.length == 1
                      ? '${birthdays.first.companyName} — '
                          'wish them today!'
                      : '${birthdays.length} colleagues across Abhishek International',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal action button — no Expanded wrapper ─────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  final String label;
  final String time;
  final Color color;

  const _TimeInfo({required this.label, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(time,
            style: GoogleFonts.inter(
                color: color, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
