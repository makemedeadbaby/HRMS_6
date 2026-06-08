import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../models/company_model.dart';
import '../../../widgets/common/app_widgets.dart';
import '../../admin/admin_shell.dart';
import '../employee_shell.dart';

class LoginScreen extends StatefulWidget {
  final CompanyModel company;
  final bool isAdmin;

  const LoginScreen({
    super.key,
    required this.company,
    this.isAdmin = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late Color _accent;

  @override
  void initState() {
    super.initState();
    try {
      final hex = widget.company.accentColorHex.replaceAll('#', '');
      _accent = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      _accent = AppColors.companyAccent(widget.company.name);
    }
    if (widget.isAdmin) _accent = AppColors.white;

    // Sync latest employees from Firestore before login (admin may have just added users).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshEmployees();
    });
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<AppProvider>();

    await provider.refreshEmployees();

    bool success;
    if (widget.isAdmin) {
      success = await provider.loginAdmin(_idCtrl.text.trim(), _passCtrl.text.trim());
    } else {
      success = await provider.loginEmployee(
        _idCtrl.text.trim(),
        _passCtrl.text.trim(),
        companyId: widget.company.id,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              widget.isAdmin ? const AdminShell() : const EmployeeShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } else {
      final diagnosis = widget.isAdmin
          ? 'Invalid admin credentials.'
          : provider.loginDiagnosis(
              _idCtrl.text.trim(),
              _passCtrl.text.trim(),
              companyId: widget.company.id,
            );
      setState(() => _error = diagnosis);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Company Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      widget.isAdmin
                          ? 'ADMIN ACCESS'
                          : widget.company.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.isAdmin ? 'Admin Login' : 'Welcome back',
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isAdmin
                        ? 'Sign in to access the admin panel'
                        : 'Sign in to mark your attendance',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Login ID
                  Text(
                    widget.isAdmin ? 'Admin ID' : 'Employee Login ID',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    hint: widget.isAdmin ? 'admin' : 'firstname.lastname',
                    controller: _idCtrl,
                    prefix: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textTertiary, size: 18),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your login ID' : null,
                  ),
                  const SizedBox(height: 20),
                  // Password
                  Text(
                    'Password',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    hint: '••••••••',
                    controller: _passCtrl,
                    obscure: _obscure,
                    prefix: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.textTertiary, size: 18),
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your password' : null,
                  ),
                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusAbsent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.statusAbsent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.statusAbsent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                color: AppColors.statusAbsent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: _loading
                        ? ''
                        : (widget.isAdmin ? 'Sign In to Admin' : 'Sign In'),
                    isLoading: _loading,
                    onTap: _login,
                    bg: _accent == AppColors.white ? AppColors.white : _accent,
                    fg: AppColors.black,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
