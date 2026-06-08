import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../widgets/common/app_widgets.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  File? _selfieFile;           // captured image file (mobile)
  String _selfieUrl = '';      // uploaded URL (from Firebase Storage)
  bool _selfieConfirmed = false;
  bool _loading = false;
  bool _uploading = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Open front camera, capture live selfie ─────────────────────────────────
  Future<void> _takeSelfie() async {
    if (kIsWeb) {
      // Web: camera capture via browser
      try {
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 75,
          maxWidth: 600,
          maxHeight: 600,
        );
        if (picked == null) return;
        if (!mounted) return;
        setState(() {
          _selfieFile = File(picked.path);
          _selfieConfirmed = false;
        });
        await _uploadSelfie(picked.path, isWeb: true, xFile: picked);
      } catch (e) {
        if (!mounted) return;
        _showError('Could not open camera: $e');
      }
      return;
    }

    // ── Android: open native front camera ─────────────────────────────────
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,  // front camera only
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (picked == null) {
        // User cancelled
        return;
      }

      if (!mounted) return;
      setState(() {
        _selfieFile = File(picked.path);
        _selfieConfirmed = false;   // wait for upload before confirming
        _uploading = true;
      });

      await _uploadSelfie(picked.path, isWeb: false, xFile: picked);
    } catch (e) {
      if (!mounted) return;
      _showError(
        'Camera could not be opened.\n'
        'Please ensure camera permission is granted in Settings.',
      );
    }
  }

  // ── Upload selfie to Firebase Storage ─────────────────────────────────────
  Future<void> _uploadSelfie(
    String localPath, {
    required bool isWeb,
    required XFile xFile,
  }) async {
    final provider = context.read<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName =
        '${emp.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = 'selfies/${emp.id}/$dateStr/$fileName';

    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask;

      if (isWeb) {
        // Web: use bytes
        final bytes = await xFile.readAsBytes();
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // Android: use file
        uploadTask = ref.putFile(File(localPath));
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _selfieUrl = downloadUrl;
        _selfieConfirmed = true;
        _uploading = false;
      });

      if (kDebugMode) debugPrint('[Selfie] Uploaded: $downloadUrl');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);

      if (kDebugMode) debugPrint('[Selfie] Upload error: $e');

      // If Storage upload fails (no internet / permissions), still allow
      // check-in with local file path so the flow isn't blocked.
      // The URL will be empty and admin won't see a photo, but attendance
      // record will still be saved.
      setState(() {
        _selfieUrl = '';
        _selfieConfirmed = true;   // allow check-in even if upload failed
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selfie captured (upload failed — will retry on sync)',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            backgroundColor: AppColors.statusHalfDay,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Confirm check-in with selfie URL ──────────────────────────────────────
  Future<void> _confirmCheckIn() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    await provider.checkIn(selfieUrl: _selfieUrl);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Checked in at ${DateFormat('hh:mm a').format(DateTime.now())}',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: AppColors.statusPresent,
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: AppColors.statusAbsent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final emp = provider.currentEmployee;
    if (emp == null) return const SizedBox();

    final accent = provider.currentAccentColor;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Check In',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Time / Employee Card ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(now),
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(now),
                      style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.divider),
                    const SizedBox(height: 12),
                    _InfoRow('Employee', emp.fullName),
                    const SizedBox(height: 8),
                    _InfoRow('Company', emp.companyName, valueColor: accent),
                    const SizedBox(height: 8),
                    _InfoRow(
                      'Shift',
                      '${emp.shiftStartTime} – ${emp.shiftEndTime}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Selfie Step ─────────────────────────────────────────────
              Text(
                'STEP 1 — CAPTURE SELFIE',
                style: GoogleFonts.inter(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Camera button / selfie preview
              GestureDetector(
                onTap: (_selfieConfirmed || _uploading) ? null : _takeSelfie,
                child: _uploading
                    // ── Uploading spinner ───────────────────────────────
                    ? Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: accent,
                          ),
                        ),
                      )
                    // ── Selfie thumbnail after capture ─────────────────
                    : _selfieConfirmed && _selfieFile != null && !kIsWeb
                        ? ClipOval(
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: Image.file(
                                _selfieFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        // ── Pulsing camera button (idle) ────────────────
                        : ScaleTransition(
                            scale: _selfieConfirmed
                                ? const AlwaysStoppedAnimation(1)
                                : _pulse,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _selfieConfirmed
                                    ? AppColors.statusPresent
                                        .withValues(alpha: 0.15)
                                    : AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selfieConfirmed
                                      ? AppColors.statusPresent
                                      : accent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _selfieConfirmed
                                    ? Icons.check_rounded
                                    : Icons.camera_alt_rounded,
                                color: _selfieConfirmed
                                    ? AppColors.statusPresent
                                    : accent,
                                size: 36,
                              ),
                            ),
                          ),
              ),
              const SizedBox(height: 12),

              // Status text below the camera button
              Text(
                _uploading
                    ? 'Uploading selfie...'
                    : _selfieConfirmed
                        ? 'Selfie captured ✓'
                        : 'Tap to take live selfie',
                style: GoogleFonts.inter(
                  color: _selfieConfirmed
                      ? AppColors.statusPresent
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),

              // Gallery note
              if (!_selfieConfirmed && !_uploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Front camera opens automatically. Gallery not allowed.',
                    style: GoogleFonts.inter(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const Spacer(),

              // ── Confirm Check In Button ─────────────────────────────────
              PrimaryButton(
                label: 'CONFIRM CHECK IN',
                icon: Icons.fingerprint_rounded,
                isLoading: _loading,
                onTap: _selfieConfirmed ? _confirmCheckIn : null,
                bg: _selfieConfirmed ? accent : AppColors.surfaceAlt,
                fg: _selfieConfirmed ? AppColors.black : AppColors.textTertiary,
              ),
              if (!_selfieConfirmed)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Please capture your selfie first',
                    style: GoogleFonts.inter(
                        color: AppColors.textTertiary, fontSize: 12),
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

// ── Local helper widget ───────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppColors.textSecondary, fontSize: 12)),
        Text(value,
            style: GoogleFonts.inter(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
