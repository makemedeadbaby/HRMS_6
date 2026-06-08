import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import 'dashboard/admin_dashboard.dart';
import 'employees/employees_screen.dart';
import 'attendance/admin_attendance_screen.dart';
import 'tickets/admin_tickets_screen.dart';
import 'notifications/admin_notifications_screen.dart';
import 'companies/companies_screen.dart';
import '../employee/auth/company_select_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _current = 0;
  bool _sidebarExpanded = true;
  AppProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider ??= context.read<AppProvider>();
      _provider!.startLiveAttendanceSync();
    });
  }

  @override
  void dispose() {
    _provider?.stopLiveAttendanceSync();
    super.dispose();
  }

  final _screens = const [
    AdminDashboard(),
    EmployeesScreen(),
    AdminAttendanceScreen(),
    AdminTicketsScreen(),
    AdminNotificationsScreen(),
    CompaniesScreen(),
  ];

  final _navItems = const [
    _NavData(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    _NavData(Icons.people_rounded, Icons.people_outlined, 'Employees'),
    _NavData(Icons.event_note_rounded, Icons.event_note_outlined, 'Attendance'),
    _NavData(Icons.confirmation_number_rounded, Icons.confirmation_number_outlined, 'Tickets'),
    _NavData(Icons.notifications_rounded, Icons.notifications_outlined, 'Notifications'),
    _NavData(Icons.business_rounded, Icons.business_outlined, 'Companies'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    if (isWide) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _sidebarExpanded ? 220 : 64,
            color: AppColors.surfaceAlt,
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Logo
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sidebarExpanded ? 16 : 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Center(
                          child: Text(
                            'AI',
                            style: GoogleFonts.inter(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      if (_sidebarExpanded) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI GROUP',
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                'Admin Panel',
                                style: GoogleFonts.inter(
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      GestureDetector(
                        onTap: () =>
                            setState(() => _sidebarExpanded = !_sidebarExpanded),
                        child: Icon(
                          _sidebarExpanded
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: AppColors.divider),
                const SizedBox(height: 12),
                // Nav Items
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (_, i) {
                      final item = _navItems[i];
                      final isActive = _current == i;
                      return GestureDetector(
                        onTap: () => setState(() => _current = i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: _sidebarExpanded ? 12 : 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                color: isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary,
                                size: 18,
                              ),
                              if (_sidebarExpanded) ...[
                                const SizedBox(width: 10),
                                Text(
                                  item.label,
                                  style: GoogleFonts.inter(
                                    color: isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Logout
                Divider(color: AppColors.divider),
                GestureDetector(
                  onTap: () => _logout(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(width: 11),
                        const Icon(Icons.logout_rounded,
                            color: AppColors.statusAbsent, size: 16),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: GoogleFonts.inter(
                                color: AppColors.statusAbsent, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: IndexedStack(
              index: _current,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceAlt,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: Text('AI',
                    style: GoogleFonts.inter(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 10),
            Text('Admin Panel',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.statusAbsent, size: 18),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: IndexedStack(index: _current, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final item = _navItems[i];
                final isActive = _current == i;
                return GestureDetector(
                  onTap: () => setState(() => _current = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? AppColors.white
                              : AppColors.textTertiary,
                          size: 20,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            color: isActive
                                ? AppColors.white
                                : AppColors.textTertiary,
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    context.read<AppProvider>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CompanySelectScreen()),
      (r) => false,
    );
  }
}

class _NavData {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavData(this.activeIcon, this.icon, this.label);
}
