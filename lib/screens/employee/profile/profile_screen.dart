import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../widgets/common/app_widgets.dart';
import '../../employee/auth/company_select_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return const SizedBox();

    final accent = provider.currentAccentColor;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              CompanyHeaderBar(
                  companyName: emp.companyName, accentColor: accent),
              const SizedBox(height: 20),
              Text(
                'Profile',
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              // ── Avatar + Basic Info ────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: accent.withValues(alpha: 0.5), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          emp.fullName[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      emp.fullName,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emp.employeeCode,
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            emp.companyName,
                            style: GoogleFonts.inter(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.statusPresent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            emp.status,
                            style: GoogleFonts.inter(
                              color: AppColors.statusPresent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // ── Tenure ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.work_history_rounded, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenure',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                        Text(
                          emp.tenureText,
                          style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Since ${DateFormat('d MMM yyyy').format(emp.joiningDate)}',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Work Info ─────────────────────────────────────────────
              DarkCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('WORK DETAILS'),
                    const SizedBox(height: 12),
                    InfoRow(label: 'Designation', value: emp.designation),
                    Divider(color: AppColors.divider, height: 1),
                    InfoRow(label: 'Department', value: emp.department),
                    Divider(color: AppColors.divider, height: 1),
                    InfoRow(
                      label: 'Shift',
                      value: '${emp.shiftType}\n${emp.shiftStartTime} – ${emp.shiftEndTime}',
                    ),
                    Divider(color: AppColors.divider, height: 1),
                    InfoRow(label: 'Branch', value: emp.branch),
                    Divider(color: AppColors.divider, height: 1),
                    InfoRow(
                        label: 'Manager', value: emp.reportingManager),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Contact Info ──────────────────────────────────────────
              DarkCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('CONTACT'),
                    const SizedBox(height: 12),
                    InfoRow(label: 'Email', value: emp.email),
                    Divider(color: AppColors.divider, height: 1),
                    InfoRow(label: 'Mobile', value: emp.mobile),
                    if (emp.emergencyContact.isNotEmpty) ...[
                      Divider(color: AppColors.divider, height: 1),
                      InfoRow(
                          label: 'Emergency',
                          value: emp.emergencyContact),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Logout ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: Text('Sign Out',
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        content: Text(
                          'Are you sure you want to sign out?',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel',
                                style: GoogleFonts.inter(
                                    color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () {
                              provider.logout();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CompanySelectScreen()),
                                (r) => false,
                              );
                            },
                            child: Text('Sign Out',
                                style: GoogleFonts.inter(
                                    color: AppColors.statusAbsent)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.statusAbsent, size: 18),
                  label: Text('Sign Out',
                      style: GoogleFonts.inter(
                          color: AppColors.statusAbsent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.statusAbsent.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: AppColors.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
