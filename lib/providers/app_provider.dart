import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/company_model.dart';
import '../models/employee_model.dart';
import '../models/attendance_model.dart';
import '../models/ticket_model.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_scheduler.dart';
// ignore: unused_import
import '../main.dart' show firebaseInitialized;

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// AppProvider — single ChangeNotifier for the whole app.
//
// DATA FLOW (all four features):
//   1. Employee:     API ↔ Hive cache ↔ UI
//   2. Attendance:   API ↔ Hive cache ↔ UI
//   3. Notification: API ↔ Hive cache ↔ UI
//   4. Ticket:       API ↔ Hive cache ↔ UI
//
// The API server (api_server.py) is the single source of truth.
// Hive is offline cache only — it is NEVER the primary source.
// Demo / mock data is seeded ONLY when the API returns empty results
// for the very first run.
// ─────────────────────────────────────────────────────────────────────────────
class AppProvider extends ChangeNotifier {

  // ─── Init ──────────────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ─── Auth ──────────────────────────────────────────────────────────────────
  EmployeeModel? _currentEmployee;
  bool _isAdmin = false;
  String _adminRole = 'super_admin';
  String _adminPassword = 'admin123';
  String _superAdminPassword = 'Super@123';

  EmployeeModel? get currentEmployee => _currentEmployee;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _currentEmployee != null || _isAdmin;
  String get adminRole => _adminRole;

  // ─── Companies ─────────────────────────────────────────────────────────────
  List<CompanyModel> _companies = [];
  List<CompanyModel> get companies =>
      _companies.where((c) => c.isActive).toList();
  List<CompanyModel> get allCompanies => _companies;

  // ─── Employees ─────────────────────────────────────────────────────────────
  List<EmployeeModel> _employees = [];
  List<EmployeeModel> get employees => _employees;

  // ─── Attendance ────────────────────────────────────────────────────────────
  List<AttendanceModel> _attendanceLogs = [];
  AttendanceModel? _todayAttendance;
  AttendanceModel? get todayAttendance => _todayAttendance;
  List<AttendanceModel> get allAttendanceLogs => _attendanceLogs;

  String get currentStatus {
    if (_todayAttendance == null) return 'Not Checked In';
    return _todayAttendance!.status;
  }

  bool get isOnBreak {
    if (_todayAttendance == null) return false;
    final b = _todayAttendance!.breaks;
    return b.isNotEmpty && b.last.endTime == null;
  }

  bool get isCheckedIn => _todayAttendance?.checkInTime != null;
  bool get isCheckedOut => _todayAttendance?.checkOutTime != null;

  // ─── Tickets ───────────────────────────────────────────────────────────────
  List<TicketModel> _tickets = [];

  List<TicketModel> get myTickets {
    if (_currentEmployee == null) return [];
    return _tickets
        .where((t) => t.employeeId == _currentEmployee!.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<TicketModel> get allTickets =>
      List<TicketModel>.from(_tickets)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ─── Notifications ─────────────────────────────────────────────────────────
  List<NotificationModel> _notifications = [];

  List<NotificationModel> get myNotifications {
    if (_currentEmployee == null) return [];
    return _notifications
        .where((n) => _notifBelongsToEmployee(n, _currentEmployee!))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<NotificationModel> get allNotifications =>
      List<NotificationModel>.from(_notifications)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get unreadCount {
    final emp = _currentEmployee;
    if (emp == null) return 0;
    return myNotifications.where((n) => !n.isReadFor(emp.id)).length;
  }

  // ─── Live attendance sync (admin panel) ────────────────────────────────────
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceStreamSub;
  Timer? _attendancePollTimer;

  // ─── Audit Logs ────────────────────────────────────────────────────────────
  List<AuditLog> _auditLogs = [];
  List<AuditLog> get auditLogs =>
      List<AuditLog>.from(_auditLogs)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  // ─── Constructor ───────────────────────────────────────────────────────────
  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    _loadCompanies();
    await _loadAdminCredentials();
    // Try Firestore first; falls back to api_server.py if not configured
    await SyncService.initFirestore();
    await _loadEmployees();
    await _loadAttendance();
    await _loadNotifications();
    await _loadTickets();
    await _loadAuditLogs();
    await _restoreSession();
    _isInitialized = true;
    notifyListeners();

    // ── Setup FCM token refresh listener ─────────────────────────────────────
    // Fires whenever FCM rotates the token (network change, reinstall, etc.)
    // We re-save it to Firestore immediately so Cloud Functions can reach the device.
    if (!kIsWeb) {
      FcmService.setupTokenRefreshHandler(
        onRefresh: (newToken) {
          final empId = _currentEmployee?.id ?? '';
          if (empId.isNotEmpty) {
            debugPrint('[AppProvider] FCM token refreshed — saving for $empId');
            FcmService.saveTokenToFirestore(employeeId: empId, token: newToken);
            // Update in-memory + SharedPreferences
            _currentEmployee = _currentEmployee!.copyWith(fcmToken: newToken);
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('current_employee',
                  jsonEncode(_currentEmployee!.toMap()));
            });
          }
        },
      );
    }
  }

  static const Set<String> _builtInCompanyIds = {'c_001', 'c_002', 'c_003', 'c_004'};

  void _loadCompanies() {
    // All four group companies stay active for employee + mobile login.
    _companies = CompanyModel.defaultCompanies
        .map((c) => c.copyWith(isActive: true))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD METHODS — API-first, Hive fallback
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadEmployees() async {
    // 1️⃣ API (shared real-time source)
    final fromApi = await SyncService.fetchEmployees();
    if (fromApi != null && fromApi.isNotEmpty) {
      _employees = fromApi.map((m) => EmployeeModel.fromMap(m)).toList();
      await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
      return;
    }
    // 2️⃣ Hive offline cache
    final cached = await _fromHive('employees_box', 'employees_list');
    if (cached != null) {
      _employees = cached.map((m) => EmployeeModel.fromMap(m)).toList();
      if (_employees.isNotEmpty) return;
    }
    // 3️⃣ First run: seed demo employees → push to API
    _employees = _demoEmployees();
    for (final e in _employees) {
      await SyncService.upsertEmployee(e.toMap());
    }
    await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
  }

  /// Pull latest employees from Firestore/API (call before login on mobile).
  Future<void> refreshEmployees() async {
    await _loadEmployees();
    notifyListeners();
  }

  List<EmployeeModel> employeesForCompany(String companyId) => _employees
      .where((e) => e.companyId == companyId && e.status == 'Active')
      .toList();

  Future<void> _loadAttendance() async {
    final fromApi = await SyncService.fetchAttendance();
    if (fromApi != null) {
      // Only load non-demo records from API
      _attendanceLogs = fromApi.map((m) => AttendanceModel.fromMap(m)).toList();
      await _cacheToHive('attendance_box', 'attendance_list', _attendanceLogs.map((a) => a.toMap()).toList());
      return;
    }
    final cached = await _fromHive('attendance_box', 'attendance_list');
    if (cached != null) {
      _attendanceLogs = cached.map((m) => AttendanceModel.fromMap(m)).toList();
    }
  }

  Future<void> _loadNotifications() async {
    final fromApi = await SyncService.fetchNotifications();
    if (fromApi != null) {
      // Preserve local read-state
      final readIds = _notifications.where((n) => n.isRead).map((n) => n.id).toSet();
      _notifications = fromApi.map((m) {
        final n = NotificationModel.fromMap(m);
        if (readIds.contains(n.id)) n.isRead = true;
        return n;
      }).toList();
      await _cacheToHive('notifications_box', 'notifications_list', _notifications.map((n) => n.toMap()).toList());
      return;
    }
    final cached = await _fromHive('notifications_box', 'notifications_list');
    if (cached != null) {
      _notifications = cached.map((m) => NotificationModel.fromMap(m)).toList();
    }
  }

  Future<void> _loadTickets() async {
    final fromApi = await SyncService.fetchTickets();
    if (fromApi != null) {
      _tickets = fromApi.map((m) => TicketModel.fromMap(m)).toList();
      await _cacheToHive('tickets_box', 'tickets_list', _tickets.map((t) => t.toMap()).toList());
      return;
    }
    final cached = await _fromHive('tickets_box', 'tickets_list');
    if (cached != null) {
      _tickets = cached.map((m) => TicketModel.fromMap(m)).toList();
    }
  }

  Future<void> _loadAuditLogs() async {
    final fromApi = await SyncService.fetchAuditLogs();
    if (fromApi != null) {
      _auditLogs = fromApi.map((m) => AuditLog.fromMap(m)).toList();
      return;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REFRESH METHODS — called on-demand from UI screens
  // ─────────────────────────────────────────────────────────────────────────

  /// Pull latest notifications from API (called when employee opens Alerts tab).
  Future<void> refreshNotifications() async {
    await _loadEmployees();
    _syncCurrentEmployeeFromLiveList();
    await _loadNotifications();
    notifyListeners();
  }

  /// Pull latest tickets from API.
  Future<void> refreshTickets() async {
    await _loadTickets();
    notifyListeners();
  }

  /// Pull latest attendance from API (admin live view).
  Future<void> refreshAttendance() async {
    await _loadAttendance();
    if (_currentEmployee != null) _loadTodayAttendance();
    notifyListeners();
  }

  /// Subscribe to Firestore (or poll API) so admin sees mobile check-ins in real time.
  Future<void> startLiveAttendanceSync() async {
    stopLiveAttendanceSync();
    await refreshAttendance();

    final today = _dateStr(DateTime.now());

    if (SyncService.firestoreReady) {
      _attendanceStreamSub =
          SyncService.streamTodayAttendance(today).listen(
        (records) {
          _mergeTodayAttendance(
            records.map((m) => AttendanceModel.fromMap(m)).toList(),
          );
          notifyListeners();
        },
        onError: (e) =>
            debugPrint('[AppProvider] live attendance stream error: $e'),
      );
      if (kDebugMode) {
        debugPrint('[AppProvider] ✅ Live attendance stream started ($today)');
      }
    }

    // Always poll as backup (stream can miss records or emit empty first).
    _attendancePollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshAttendance(),
    );
  }

  void stopLiveAttendanceSync() {
    _attendanceStreamSub?.cancel();
    _attendanceStreamSub = null;
    _attendancePollTimer?.cancel();
    _attendancePollTimer = null;
  }

  void _mergeTodayAttendance(List<AttendanceModel> todayRecords) {
    // Firestore streams often emit an empty snapshot first — never wipe data on that.
    if (todayRecords.isEmpty) return;

    final today = _dateStr(DateTime.now());
    _attendanceLogs.removeWhere((a) => _attendanceDateKey(a) == today);
    _attendanceLogs.addAll(todayRecords);
    final real = _attendanceLogs.where((a) => !a.id.startsWith('att_')).toList();
    _cacheToHive(
      'attendance_box',
      'attendance_list',
      real.map((a) => a.toMap()).toList(),
    );
  }

  String _attendanceDateKey(AttendanceModel a) => _dateStr(a.date);

  // ─────────────────────────────────────────────────────────────────────────
  // HIVE CACHE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cacheToHive(String boxName, String key, List<Map<String, dynamic>> data) async {
    try {
      final box = await Hive.openBox(boxName);
      await box.put(key, jsonEncode(data));
      await box.flush();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> _fromHive(String boxName, String key) async {
    try {
      final box = await Hive.openBox(boxName);
      final raw = box.get(key);
      if (raw != null && raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _adminPassword = prefs.getString('admin_password') ?? 'admin123';
    _superAdminPassword = prefs.getString('super_admin_password') ?? 'admin123';

    // Also try to load from Firestore admin_settings
    try {
      final doc = await FirestoreService.getAdminSettings();
      if (doc != null) {
        final fsPass = doc['adminPassword'] as String?;
        if (fsPass != null && fsPass.isNotEmpty) {
          _adminPassword = fsPass;
          await prefs.setString('admin_password', fsPass);
        }
      }
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final empJson = prefs.getString('current_employee');
    final isAdm = prefs.getBool('is_admin') ?? false;

    if (empJson != null && !isAdm) {
      try {
        final restored = EmployeeModel.fromMap(jsonDecode(empJson));
        // Refresh from live employee list so password/data changes apply
        EmployeeModel? liveEmp =
            _employees.where((e) => e.id == restored.id).firstOrNull ??
            restored;

        // ── Fix 1: Guarantee company name is always correct ──────────────────
        if (liveEmp.companyName.isEmpty || liveEmp.companyName == 'Unknown') {
          final company =
              _companies.where((c) => c.id == liveEmp!.companyId).firstOrNull;
          if (company != null) {
            liveEmp = liveEmp.copyWith(companyName: company.name);
          }
        }
        // ─────────────────────────────────────────────────────────────────────

        _currentEmployee = liveEmp;
        _loadTodayAttendance();
      } catch (_) {
        await prefs.remove('current_employee');
      }
    }
    // Admin panel is web-only; Android/iOS always use the employee app.
    if (isAdm && kIsWeb) {
      _isAdmin = true;
      _adminRole = prefs.getString('admin_role') ?? 'super_admin';
    } else if (isAdm && !kIsWeb) {
      await prefs.remove('is_admin');
      await prefs.remove('admin_role');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> loginEmployee(
    String loginId,
    String password, {
    String? companyId,
  }) async {
    final id   = loginId.trim().toLowerCase();
    final pass = password.trim();
    EmployeeModel? emp = _employees.where((e) =>
      e.loginId.trim().toLowerCase() == id &&
      e.passwordHash.trim() == pass &&
      e.status == 'Active' &&
      (companyId == null || e.companyId == companyId)
    ).firstOrNull;

    if (emp == null) return false;

    // ── Fix 1: Guarantee company name is always correct from companyId ────────
    // If Firestore/cache has stale/empty companyName, derive it from companyId.
    if (emp.companyName.isEmpty || emp.companyName == 'Unknown') {
      final company = _companies.where((c) => c.id == emp!.companyId).firstOrNull;
      if (company != null) {
        emp = emp.copyWith(companyName: company.name);
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    _currentEmployee = emp;
    _isAdmin = false;
    _todayAttendance = null;
    _loadTodayAttendance();
    await _loadNotifications();
    _syncCurrentEmployeeFromLiveList();

    final prefs = await SharedPreferences.getInstance();
    final savedEmp = _currentEmployee ?? emp;
    await prefs.setString('current_employee', jsonEncode(savedEmp.toMap()));
    await prefs.setBool('is_admin', false);
    notifyListeners();

    // ── Fix 3: Save FCM token for this employee ────────────────────────────
    _saveFcmTokenForEmployee(emp.id);
    // ────────────────────────────────────────────────────────────────────────

    return true;
  }

  Future<bool> loginAdmin(String loginId, String password) async {
    final isAdmin      = loginId == 'admin'      && password == _adminPassword;
    final isSuperAdmin = loginId == 'superadmin' && password == _superAdminPassword;
    if (!isAdmin && !isSuperAdmin) return false;

    _isAdmin = true;
    _adminRole = 'super_admin';
    _currentEmployee = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_admin', true);
    await prefs.setString('admin_role', 'super_admin');
    notifyListeners();
    return true;
  }

  Future<void> resetAdminPassword({
    required String loginId,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (loginId == 'admin') {
      _adminPassword = newPassword;
      await prefs.setString('admin_password', newPassword);
    } else if (loginId == 'superadmin') {
      _superAdminPassword = newPassword;
      await prefs.setString('super_admin_password', newPassword);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _currentEmployee = null;
    _isAdmin = false;
    _todayAttendance = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_employee');
    await prefs.remove('is_admin');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEE MANAGEMENT (admin)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addEmployee(EmployeeModel emp) async {
    _employees.add(emp);
    await SyncService.upsertEmployee(emp.toMap());
    await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> updateEmployee(EmployeeModel updated) async {
    final idx = _employees.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) _employees[idx] = updated;
    await SyncService.upsertEmployee(updated.toMap());
    await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> deleteEmployee(String employeeId) async {
    _employees.removeWhere((e) => e.id == employeeId);
    await SyncService.deleteEmployee(employeeId);
    await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  Future<void> resetEmployeePassword(String employeeId, String newPassword) async {
    final idx = _employees.indexWhere((e) => e.id == employeeId);
    if (idx >= 0) {
      _employees[idx] = _employees[idx].copyWith(passwordHash: newPassword);
    }
    await SyncService.updateEmployeePassword(employeeId, newPassword);
    await _cacheToHive('employees_box', 'employees_list', _employees.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  // ── Fix 3: Save FCM token to Firestore on login ─────────────────────────
  Future<void> _saveFcmTokenForEmployee(String employeeId) async {
    try {
      final token = await FcmService.getToken();
      if (token == null || token.isEmpty) return;

      // Update in-memory employee list with new token
      final idx = _employees.indexWhere((e) => e.id == employeeId);
      if (idx >= 0) {
        _employees[idx] = _employees[idx].copyWith(fcmToken: token);
      }
      if (_currentEmployee?.id == employeeId) {
        _currentEmployee = _currentEmployee!.copyWith(fcmToken: token);
        // Persist updated employee to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'current_employee', jsonEncode(_currentEmployee!.toMap()));
      }

      // Save token to Firestore
      await FcmService.saveTokenToFirestore(
          employeeId: employeeId, token: token);

      // Also persist via SyncService so api_server.py fallback gets it
      await SyncService.upsertEmployee(
          _employees.firstWhere((e) => e.id == employeeId).toMap());

      if (kDebugMode) debugPrint('[FCM] Token registered for $employeeId');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] _saveFcmTokenForEmployee error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTENDANCE — employee self-service
  // ─────────────────────────────────────────────────────────────────────────

  void _loadTodayAttendance() {
    if (_currentEmployee == null) return;
    final today = DateTime.now();
    final todayStr = _dateStr(today);

    _todayAttendance = _attendanceLogs.where((a) =>
      a.employeeId == _currentEmployee!.id &&
      a.date.toIso8601String().substring(0, 10) == todayStr
    ).firstOrNull;

    // Night-shift: check yesterday's unchecked-out record
    if (_todayAttendance == null) {
      final yStr = _dateStr(today.subtract(const Duration(days: 1)));
      final yRec = _attendanceLogs.where((a) =>
        a.employeeId == _currentEmployee!.id &&
        a.date.toIso8601String().substring(0, 10) == yStr
      ).firstOrNull;
      if (yRec != null && yRec.checkOutTime == null) {
        _todayAttendance = yRec;
      }
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> checkIn({String selfieUrl = '', double? lat, double? lng}) async {
    if (_currentEmployee == null) return;
    final now = DateTime.now();
    final att = AttendanceModel(
      id: _uuid.v4(),
      employeeId: _currentEmployee!.id,
      employeeName: _currentEmployee!.fullName,
      companyId: _currentEmployee!.companyId,
      companyName: _currentEmployee!.companyName,
      department: _currentEmployee!.department,
      date: now,
      checkInTime: now,
      status: 'Present',
      checkInSelfieUrl: selfieUrl,
      checkInLat: lat,
      checkInLng: lng,
    );
    _todayAttendance = att;
    _attendanceLogs.add(att);
    await _persistAttendanceRecord(att);
    notifyListeners();

    // Schedule logout + shift reminders via FCM.
    // The Cloud Function onEmployeeCheckIn is the SERVER-SIDE guarantee —
    // it fires on the attendance doc creation and reads the FCM token from
    // Firestore directly, so it works even if the client token isn't cached yet.
    //
    // We still call the client-side scheduler as an additional attempt,
    // but WITHOUT the fcmToken guard — the scheduler handles empty tokens gracefully.
    if (!kIsWeb && _currentEmployee != null) {
      final empId   = _currentEmployee!.id;
      final token   = _currentEmployee!.fcmToken; // may be empty on first login
      final shiftEnd   = _currentEmployee!.shiftEndTime;
      final shiftStart = _currentEmployee!.shiftStartTime;
      final shiftType  = _currentEmployee!.shiftType;

      debugPrint('[CheckIn] Scheduling reminders — empId=$empId token='
          '${token.isEmpty ? "EMPTY (Cloud Function will handle)" : "${token.substring(0, 20)}..."}');

      // Even with empty token the scheduler writes to Firestore scheduled_notifications
      // Cloud Function picks it up and uses the token stored in the employee doc
      NotificationScheduler.scheduleLogoutReminder(
        employeeId: empId,
        fcmToken: token, // empty is OK — CF reads fresh from Firestore
        shiftEndTime: shiftEnd,
      );
      NotificationScheduler.scheduleShiftReminder(
        employeeId: empId,
        fcmToken: token,
        shiftStartTime: shiftStart,
        shiftType: shiftType,
      );
    }
  }

  Future<void> startBreak() async {
    if (_todayAttendance == null) return;
    _todayAttendance!.status = 'On Break';
    _todayAttendance!.breaks.add(BreakLog(id: _uuid.v4(), startTime: DateTime.now()));
    await _persistAttendanceRecord(_todayAttendance!);
    notifyListeners();

    // Start break timer + schedule FCM push when break ends
    if (_currentEmployee != null && !kIsWeb) {
      NotificationScheduler.startBreakTimer(
        employeeId: _currentEmployee!.id,
        fcmToken: _currentEmployee!.fcmToken,
        maxBreakMinutes: 30,
      );
    }
  }

  Future<void> endBreak() async {
    if (_todayAttendance == null) return;
    final b = _todayAttendance!.breaks;
    if (b.isNotEmpty && b.last.endTime == null) {
      b.last.endTime = DateTime.now();
      _todayAttendance!.totalBreakMinutes =
          b.fold(0, (s, bl) => s + bl.durationMinutes);
    }
    _todayAttendance!.status = 'Present';
    await _persistAttendanceRecord(_todayAttendance!);
    notifyListeners();

    // Stop break timer + cancel scheduled push
    if (_currentEmployee != null) {
      NotificationScheduler.stopBreakTimer(
        employeeId: _currentEmployee!.id,
      );
    }
  }

  // ── Break timer stream (for live UI display) ───────────────────────────────
  Stream<Duration> get breakElapsedStream =>
      NotificationScheduler.breakElapsedStream;

  Duration get currentBreakElapsed => NotificationScheduler.currentBreakElapsed;

  Future<void> checkOut() async {
    if (_todayAttendance == null) return;
    if (isOnBreak) await endBreak();
    _todayAttendance!.checkOutTime = DateTime.now();
    _todayAttendance!.status = 'Checked Out';
    await _persistAttendanceRecord(_todayAttendance!);
    notifyListeners();
  }

  /// Persist a single attendance record to API + Hive cache.
  Future<void> _persistAttendanceRecord(AttendanceModel att) async {
    final synced = await SyncService.upsertAttendance(att.toMap());
    if (!synced) {
      debugPrint(
        '[AppProvider] ⚠️ Attendance not synced to cloud (${att.employeeName}). '
        'Admin panel will not update until sync succeeds.',
      );
    }
    // Update in-memory list
    final idx = _attendanceLogs.indexWhere((a) => a.id == att.id);
    if (idx >= 0) _attendanceLogs[idx] = att;
    // Cache all non-demo records
    final real = _attendanceLogs.where((a) => !a.id.startsWith('att_')).toList();
    await _cacheToHive('attendance_box', 'attendance_list', real.map((a) => a.toMap()).toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTENDANCE — admin manual marking
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> adminMarkAttendance({
    required String employeeId,
    required DateTime date,
    required String newStatus,
    String? checkInTime,
    String? checkOutTime,
    String reason = '',
    required String adminName,
  }) async {
    final dateStr = _dateStr(date);
    final emp = _employees.where((e) => e.id == employeeId).firstOrNull;
    if (emp == null) return;

    AttendanceModel? existing = _attendanceLogs.where((a) =>
      a.employeeId == employeeId &&
      a.date.toIso8601String().substring(0, 10) == dateStr
    ).firstOrNull;

    final prevStatus = existing?.status ?? 'Not Marked';

    if (existing != null) {
      existing.status = newStatus;
      existing.isManuallyMarked = true;
      existing.markedBy = adminName;
      existing.markedReason = reason;
      existing.markedAt = DateTime.now();
      existing.previousStatus = prevStatus;
    } else {
      existing = AttendanceModel(
        id: _uuid.v4(),
        employeeId: employeeId,
        employeeName: emp.fullName,
        companyId: emp.companyId,
        companyName: emp.companyName,
        department: emp.department,
        date: date,
        status: newStatus,
        isManuallyMarked: true,
        markedBy: adminName,
        markedReason: reason,
        markedAt: DateTime.now(),
        previousStatus: prevStatus,
      );
      _attendanceLogs.add(existing);
    }

    final auditEntry = AuditLog(
      id: _uuid.v4(),
      attendanceId: existing.id,
      employeeId: employeeId,
      employeeName: emp.fullName,
      previousStatus: prevStatus,
      newStatus: newStatus,
      updatedBy: adminName,
      updatedAt: DateTime.now(),
      reason: reason,
    );
    _auditLogs.add(auditEntry);

    // Push to API atomically (attendance + audit in one call)
    await SyncService.adminMarkAttendance(
      attendance: existing.toMap(),
      auditEntry: auditEntry.toMap(),
    );

    // Refresh today's attendance for logged-in employee
    if (_currentEmployee != null) _loadTodayAttendance();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  bool _employeeExistedWhenNotifSent(NotificationModel n, EmployeeModel emp) {
    final start = emp.accountStartDate;
    final accountDay = DateTime(start.year, start.month, start.day);
    final sent = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
    // Notification must be sent on or after the day this account was created.
    return !sent.isBefore(accountDay);
  }

  bool _notifBelongsToEmployee(NotificationModel n, EmployeeModel emp) {
    final type = n.targetType.toLowerCase();

    if (type == 'individual' || type == 'employee') {
      return n.targetValue == emp.id;
    }

    if (type == 'global' || type == 'all') {
      if (n.recipientEmployeeIds.isNotEmpty) {
        return n.recipientEmployeeIds.contains(emp.id);
      }
      return _employeeExistedWhenNotifSent(n, emp);
    }

    switch (type) {
      case 'company':
        return (n.targetValue == emp.companyId ||
                n.targetValue == emp.companyName) &&
            _employeeExistedWhenNotifSent(n, emp);
      case 'department':
        return n.targetValue == emp.department &&
            _employeeExistedWhenNotifSent(n, emp);
      case 'shift':
        return n.targetValue == emp.shiftType &&
            _employeeExistedWhenNotifSent(n, emp);
      default:
        return false;
    }
  }

  void _syncCurrentEmployeeFromLiveList() {
    final current = _currentEmployee;
    if (current == null) return;
    final live = _employees.where((e) => e.id == current.id).firstOrNull;
    if (live != null) _currentEmployee = live;
  }

  Future<void> sendNotification({
    required String title,
    required String message,
    required String priority,
    required String targetType,
    required String targetValue,
    required String createdBy,
    String attachmentUrl = '',
  }) async {
    final type = targetType.toLowerCase();
    final List<String> recipientIds;
    if (type == 'individual' || type == 'employee') {
      recipientIds = targetValue.isNotEmpty ? [targetValue] : [];
    } else if (type == 'company') {
      recipientIds = _employees
          .where((e) => e.companyName == targetValue)
          .map((e) => e.id).toList();
    } else if (type == 'department') {
      recipientIds = _employees
          .where((e) => e.department == targetValue)
          .map((e) => e.id).toList();
    } else if (type == 'shift') {
      recipientIds = _employees
          .where((e) => e.shiftType == targetValue)
          .map((e) => e.id).toList();
    } else {
      // global — all employees
      recipientIds = _employees.map((e) => e.id).toList();
    }

    final notif = NotificationModel(
      id: _uuid.v4(),
      title: title,
      message: message,
      priority: priority,
      targetType: targetType,
      targetValue: targetValue,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      attachmentUrl: attachmentUrl,
      recipientEmployeeIds: recipientIds,
    );
    _notifications.add(notif);
    await SyncService.upsertNotification(notif.toMap());
    await _cacheToHive('notifications_box', 'notifications_list',
        _notifications.map((n) => n.toMap()).toList());

    // ── Fix 3: Send FCM push to targeted devices ──────────────────────────
    try {
      await FcmService.sendPushToTargets(
        title: title,
        message: message,
        targetType: targetType,
        targetValue: targetValue,
        priority: priority,
        allEmployees: _employees.map((e) => e.toMap()).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] sendPushToTargets error: $e');
    }
    // ─────────────────────────────────────────────────────────────────────

    notifyListeners();
  }

  void markNotificationRead(String id) {
    final empId = _currentEmployee?.id;
    if (empId == null) return;
    final n = _notifications.where((n) => n.id == id).firstOrNull;
    if (n != null) {
      if (n.isIndividual) {
        n.isRead = true;
        n.readAt = DateTime.now();
      } else if (!n.readByEmployeeIds.contains(empId)) {
        n.readByEmployeeIds.add(empId);
      }
      SyncService.upsertNotification(n.toMap());
      _cacheToHive('notifications_box', 'notifications_list', _notifications.map((n) => n.toMap()).toList());
      notifyListeners();
    }
  }

  void markAllRead() {
    final empId = _currentEmployee?.id;
    if (empId == null) return;
    for (final n in myNotifications) {
      if (n.isIndividual) {
        n.isRead = true;
        n.readAt = DateTime.now();
      } else if (!n.readByEmployeeIds.contains(empId)) {
        n.readByEmployeeIds.add(empId);
      }
    }
    SyncService.bulkSaveNotifications(_notifications.map((n) => n.toMap()).toList());
    _cacheToHive('notifications_box', 'notifications_list', _notifications.map((n) => n.toMap()).toList());
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TICKETS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> raiseTicket({
    required String category,
    required String subject,
    required String description,
    required String priority,
    String attachmentUrl = '',
  }) async {
    if (_currentEmployee == null) return;
    final ticket = TicketModel(
      id: _uuid.v4(),
      employeeId: _currentEmployee!.id,
      employeeName: _currentEmployee!.fullName,
      companyId: _currentEmployee!.companyId,
      companyName: _currentEmployee!.companyName,
      category: category,
      subject: subject,
      description: description,
      attachmentUrl: attachmentUrl,
      status: 'Open',
      priority: priority,
      createdAt: DateTime.now(),
    );
    _tickets.add(ticket);
    // Push to API so admin sees it immediately
    await SyncService.upsertTicket(ticket.toMap());
    await _cacheToHive('tickets_box', 'tickets_list', _tickets.map((t) => t.toMap()).toList());
    notifyListeners();
  }

  Future<void> adminReplyTicket(
    String ticketId,
    String reply,
    String adminName,
  ) async {
    final t = _tickets.where((t) => t.id == ticketId).firstOrNull;
    if (t == null) return;
    final now = DateTime.now();
    t.adminReply = reply;
    t.repliedBy = adminName;
    t.status = 'In Progress';
    final msg = {
      'sender': 'admin',
      'message': reply,
      'time': '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
    };
    t.messages.add(msg);

    await SyncService.adminReplyTicket(
      ticketId: ticketId,
      reply: reply,
      repliedBy: adminName,
      newStatus: 'In Progress',
      message: msg,
    );
    await _cacheToHive('tickets_box', 'tickets_list', _tickets.map((t) => t.toMap()).toList());
    notifyListeners();
  }

  // Named alias used by some screens
  void adminReplyTicketNamed({
    required String ticketId,
    required String reply,
    required String adminName,
  }) => adminReplyTicket(ticketId, reply, adminName);

  Future<void> adminUpdateTicketStatus(String ticketId, String status) async {
    final t = _tickets.where((t) => t.id == ticketId).firstOrNull;
    if (t == null) return;
    t.status = status;
    DateTime? resolvedAt;
    if (status == 'Resolved' || status == 'Closed') {
      resolvedAt = DateTime.now();
      t.resolvedAt = resolvedAt;
    }
    await SyncService.updateTicketStatus(
      ticketId: ticketId,
      status: status,
      resolvedAt: resolvedAt?.toIso8601String(),
    );
    await _cacheToHive('tickets_box', 'tickets_list', _tickets.map((t) => t.toMap()).toList());
    notifyListeners();
  }

  // Alias
  void updateTicketStatus(String ticketId, String status) =>
      adminUpdateTicketStatus(ticketId, status);

  // ─────────────────────────────────────────────────────────────────────────
  // COMPANY MANAGEMENT
  // ─────────────────────────────────────────────────────────────────────────

  void addCompany(CompanyModel company) {
    _companies.add(company);
    notifyListeners();
  }

  void toggleCompanyStatus(String companyId) {
    if (_builtInCompanyIds.contains(companyId)) return;
    final idx = _companies.indexWhere((c) => c.id == companyId);
    if (idx >= 0) {
      final c = _companies[idx];
      _companies[idx] = c.copyWith(isActive: !c.isActive);
    }
    notifyListeners();
  }

  bool isBuiltInCompany(String companyId) =>
      _builtInCompanyIds.contains(companyId);

  void updateCompany(CompanyModel updated) {
    final idx = _companies.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) _companies[idx] = updated;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATTENDANCE QUERY HELPERS (used by admin screens)
  // ─────────────────────────────────────────────────────────────────────────

  List<AttendanceModel> getEmployeeAttendance(String employeeId) =>
      _attendanceLogs
          .where((a) => a.employeeId == employeeId)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<AttendanceModel> getTodayAllAttendance() {
    final t = _dateStr(DateTime.now());
    return _attendanceLogs
        .where((a) => _attendanceDateKey(a) == t)
        .toList();
  }

  Map<String, int> getTodayStats() {
    final logs = getTodayAllAttendance();
    return {
      'total': _employees.where((e) => e.status == 'Active').length,
      'present': logs.where((a) =>
          a.status == 'Present' ||
          a.status == 'On Break' ||
          a.checkInTime != null).length,
      'absent': logs.where((a) => a.status == 'Absent').length,
      'half_day': logs.where((a) => a.status == 'Half Day').length,
      'on_break': logs.where((a) => a.status == 'On Break').length,
      'checked_out': logs.where((a) => a.status == 'Checked Out').length,
      'late': logs.where((a) => a.status == 'Late').length,
    };
  }

  Map<String, int> getEmployeeMonthlyStats(String employeeId, int month, int year) {
    final logs = _attendanceLogs.where((a) =>
      a.employeeId == employeeId &&
      a.date.month == month &&
      a.date.year == year
    ).toList();
    return {
      'present': logs.where((a) => a.status == 'Present' || a.status == 'Checked Out').length,
      'absent': logs.where((a) => a.status == 'Absent').length,
      'half_day': logs.where((a) => a.status == 'Half Day').length,
      'late': logs.where((a) => a.status == 'Late').length,
      'total_working_mins': logs.fold(0, (s, a) => s + a.totalWorkingMinutes),
      'total_break_mins': logs.fold(0, (s, a) => s + a.totalBreakMinutes),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLOR HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Color getCompanyAccentByName(String name) {
    final c = _companies.where((c) => c.name == name).firstOrNull;
    if (c == null) return AppColors.companyAccent(name);
    return getCompanyAccent(c.id);
  }

  Color getCompanyAccent(String companyId) {
    final c = _companies.where((c) => c.id == companyId).firstOrNull;
    if (c == null) return AppColors.accentDefault;
    try {
      final hex = c.accentColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.companyAccent(c.name);
    }
  }

  Color get currentAccentColor {
    if (_currentEmployee == null) return AppColors.accentDefault;
    return getCompanyAccent(_currentEmployee!.companyId);
  }

  // ── Today's birthdays across ALL companies ─────────────────────────────────
  /// Returns all employees (across all 4 companies) whose birthday is today.
  List<EmployeeModel> get todaysBirthdays {
    return _employees.where((e) => e.isBirthdayToday).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG HELPER
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a human-readable diagnosis of why employee login failed.
  String loginDiagnosis(
    String loginId,
    String password, {
    String? companyId,
  }) {
    final id   = loginId.trim().toLowerCase();
    final pass = password.trim();
    final pool = companyId == null
        ? _employees
        : _employees.where((e) => e.companyId == companyId).toList();

    if (pool.isEmpty) {
      return companyId == null
          ? 'No employees loaded. Check internet and try again.'
          : 'No employees found for this company. Ask admin to add you in the web panel.';
    }

    final byId = pool.where((e) => e.loginId.trim().toLowerCase() == id).toList();
    if (byId.isEmpty) {
      final known = pool.map((e) => e.loginId).where((id) => id.isNotEmpty).join(', ');
      return 'Login ID "$id" not found for this company. '
             'Use the Login ID from Admin → Employees (e.g. $known)';
    }
    final byPass = byId.where((e) => e.passwordHash.trim() == pass).toList();
    if (byPass.isEmpty) return 'Login ID found but password is wrong. Use the password set in Admin panel.';
    final inactive = byPass.where((e) => e.status != 'Active').toList();
    if (inactive.isNotEmpty) return 'Account is not Active';
    return 'Unknown mismatch';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEMO SEED DATA (first-run only)
  // ─────────────────────────────────────────────────────────────────────────

  List<EmployeeModel> _demoEmployees() => [
    EmployeeModel(
      id: 'emp_001', employeeCode: 'EMP-1001', fullName: 'Rahul Sharma',
      email: 'rahul@learningsaint.com', mobile: '9876543210',
      companyId: 'c_001', companyName: 'Learning Saint',
      department: 'US Dept', designation: 'Sales Executive',
      shiftType: 'Night Shift', shiftStartTime: '8:30 PM', shiftEndTime: '5:30 AM',
      reportingManager: 'Abhishek Boss', branch: 'Noida',
      loginId: 'rahul.sharma', passwordHash: 'Pass@123',
      status: 'Active', joiningDate: DateTime(2026, 1, 1),
    ),
    EmployeeModel(
      id: 'emp_002', employeeCode: 'EMP-1002', fullName: 'Priya Singh',
      email: 'priya@khushlifestyle.com', mobile: '9876543211',
      companyId: 'c_002', companyName: 'Khush Lifestyle',
      department: 'Marketing Dept', designation: 'Marketing Executive',
      shiftType: 'Day Shift', shiftStartTime: '9:30 AM', shiftEndTime: '6:30 PM',
      reportingManager: 'Abhishek Boss', branch: 'Noida',
      loginId: 'priya.singh', passwordHash: 'Pass@123',
      status: 'Active', joiningDate: DateTime(2025, 11, 15),
    ),
    EmployeeModel(
      id: 'emp_003', employeeCode: 'EMP-1003', fullName: 'Amit Kumar',
      email: 'amit@vibgyor.com', mobile: '9876543212',
      companyId: 'c_003', companyName: 'Vibgyor',
      department: 'IT Dept', designation: 'Designer',
      shiftType: 'Day Shift', shiftStartTime: '10:00 AM', shiftEndTime: '7:00 PM',
      reportingManager: 'Abhishek Boss', branch: 'Kanpur',
      loginId: 'amit.kumar', passwordHash: 'Pass@123',
      status: 'Active', joiningDate: DateTime(2025, 9, 1),
    ),
    EmployeeModel(
      id: 'emp_004', employeeCode: 'EMP-1004', fullName: 'Neha Gupta',
      email: 'neha@possessivepanda.com', mobile: '9876543213',
      companyId: 'c_004', companyName: 'Possessive Panda',
      department: 'Domestic Dept', designation: 'Sales Manager',
      shiftType: 'Day Shift', shiftStartTime: '10:00 AM', shiftEndTime: '7:00 PM',
      reportingManager: 'Abhishek Boss', branch: 'Noida',
      loginId: 'neha.gupta', passwordHash: 'Pass@123',
      status: 'Active', joiningDate: DateTime(2025, 6, 10),
    ),
    EmployeeModel(
      id: 'emp_005', employeeCode: 'EMP-1005', fullName: 'Ravi Verma',
      email: 'ravi@learningsaint.com', mobile: '9876543214',
      companyId: 'c_001', companyName: 'Learning Saint',
      department: 'UK Dept', designation: 'Senior Sales Executive',
      shiftType: 'Night Shift', shiftStartTime: '8:30 PM', shiftEndTime: '5:30 AM',
      reportingManager: 'Abhishek Boss', branch: 'Noida',
      loginId: 'ravi.verma', passwordHash: 'Pass@123',
      status: 'Active', joiningDate: DateTime(2024, 3, 20),
    ),
  ];
}
