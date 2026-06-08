// ═══════════════════════════════════════════════════════════════════════════
// sync_service.dart  —  Unified Data Layer  v3.0
//
// ARCHITECTURE:
//   Primary source  → Firestore (real-time, shared between web + APK)
//   Fallback source → Local HTTP api_server.py (works when Firebase not yet configured)
//
// When Firebase is configured (firebase_options.dart filled in):
//   → All reads/writes go to Firestore automatically
//
// When Firebase is NOT yet configured (placeholder values):
//   → Falls back to local Python api_server.py (same as before)
//
// This dual-mode design means the app works in both states without
// any code changes — just fill in firebase_options.dart and restart.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../main.dart' show firebaseInitialized;
import 'firestore_service.dart';

class SyncService {
  // ── HTTP fallback base URL ─────────────────────────────────────────────────
  // Used ONLY when Firestore is unavailable (rules not set / network down).
  //
  // On WEB:     empty string  → relative URL  → served by same HTTP server
  //             (run: python3 -m http.server 5060 --directory build/web)
  //             or start api_server.py on the same origin.
  //
  // On ANDROID: set this to the IP address of the machine running api_server.py
  //             on your local network, e.g. 'http://192.168.1.10:5060'
  //             Leave empty to disable HTTP fallback on Android.
  //
  static const String _androidFallbackBase = ''; // ← set your LAN IP if needed

  static String get _base => kIsWeb ? '' : _androidFallbackBase;

  // Whether the HTTP fallback is usable at all.
  static bool get _httpFallbackEnabled => _base.isNotEmpty || kIsWeb;

  static final _client = http.Client();
  static const _timeout = Duration(seconds: 10);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };

  // ── Firestore availability flag ────────────────────────────────────────────
  // Set to true once Firebase has been initialized AND Firestore is reachable.
  // The app checks this once at startup in AppProvider._init().
  static bool _firestoreReady = false;
  static bool get firestoreReady => _firestoreReady;

  /// Call this from AppProvider._init() after Firebase.initializeApp().
  /// Returns true if Firestore is reachable (credentials are valid and rules allow access).
  static Future<bool> initFirestore() async {
    // Guard: never attempt Firestore if Firebase did not initialize.
    if (!firebaseInitialized) {
      debugPrint('[SyncService] ⚠️  Firebase not initialized — skipping Firestore, using HTTP fallback');
      _firestoreReady = false;
      return false;
    }
    try {
      final reachable = await FirestoreService.isReachable();
      _firestoreReady = reachable;
      if (reachable) {
        debugPrint('[SyncService] ✅ Firestore connected — using cloud storage');
      } else {
        debugPrint('[SyncService] ⚠️  Firestore not reachable — '
            '${_httpFallbackEnabled ? "using HTTP fallback" : "no fallback available"}');
      }
      return reachable;
    } catch (e) {
      debugPrint('[SyncService] ❌ Firestore init error: $e');
      _firestoreReady = false;
      return false;
    }
  }

  // ── Internal HTTP helpers (fallback) ──────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> _getList(String endpoint) async {
    if (!_httpFallbackEnabled) {
      debugPrint('[SyncService] HTTP fallback disabled — no base URL configured for Android');
      return null;
    }
    try {
      final url = Uri.parse('$_base$endpoint');
      debugPrint('[SyncService] HTTP GET $url');
      final res = await _client
          .get(url, headers: _headers)
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      debugPrint('[SyncService] HTTP GET $url → ${res.statusCode}');
    } catch (e) {
      debugPrint('[SyncService] HTTP GET $endpoint error: $e');
    }
    return null;
  }

  static Future<bool> _post(String endpoint, dynamic body) async {
    if (!_httpFallbackEnabled) {
      debugPrint('[SyncService] HTTP fallback disabled — no base URL configured for Android');
      return false;
    }
    try {
      final url = Uri.parse('$_base$endpoint');
      debugPrint('[SyncService] HTTP POST $url');
      final res = await _client
          .post(
            url,
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map;
        return decoded['ok'] == true;
      }
      debugPrint('[SyncService] HTTP POST $endpoint → ${res.statusCode}');
    } catch (e) {
      debugPrint('[SyncService] HTTP POST $endpoint error: $e');
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ─────────────────────────────────────────────────────────────────────────

  static Future<bool> isReachable() async {
    if (_firestoreReady) return FirestoreService.isReachable();
    if (!_httpFallbackEnabled) return false;
    try {
      final res = await _client
          .get(Uri.parse('$_base/api/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEES
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> fetchEmployees() =>
      _firestoreReady
          ? FirestoreService.fetchEmployees()
          : _getList('/api/employees');

  static Future<bool> upsertEmployee(Map<String, dynamic> emp) =>
      _firestoreReady
          ? FirestoreService.upsertEmployee(emp)
          : _post('/api/employees', emp);

  static Future<bool> deleteEmployee(String id) =>
      _firestoreReady
          ? FirestoreService.deleteEmployee(id)
          : _post('/api/employees/delete', {'id': id});

  static Future<bool> updateEmployeePassword(String id, String hash) =>
      _firestoreReady
          ? FirestoreService.updateEmployeePassword(id, hash)
          : _post('/api/employees/password', {'id': id, 'password_hash': hash});

  // ─────────────────────────────────────────────────────────────────────────
  // ATTENDANCE
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> fetchAttendance({
    String? employeeId,
    String? date,
  }) async {
    if (_firestoreReady) {
      return FirestoreService.fetchAttendance(
          employeeId: employeeId, date: date);
    }
    var endpoint = '/api/attendance';
    final params = <String>[];
    if (employeeId != null) params.add('employee_id=$employeeId');
    if (date != null) params.add('date=$date');
    if (params.isNotEmpty) endpoint += '?${params.join('&')}';
    return _getList(endpoint);
  }

  static Future<bool> upsertAttendance(Map<String, dynamic> att) =>
      _firestoreReady
          ? FirestoreService.upsertAttendance(att)
          : _post('/api/attendance', att);

  /// Real-time stream of today's attendance (admin panel live view).
  static Stream<List<Map<String, dynamic>>> streamTodayAttendance(String date) {
    if (!_firestoreReady) return const Stream.empty();
    return FirestoreService.streamTodayAttendance(date);
  }

  static Future<bool> adminMarkAttendance({
    required Map<String, dynamic> attendance,
    required Map<String, dynamic> auditEntry,
  }) =>
      _firestoreReady
          ? FirestoreService.adminMarkAttendance(
              attendance: attendance, auditEntry: auditEntry)
          : _post('/api/attendance/admin-mark', {
              'attendance': attendance,
              'audit': auditEntry,
            });

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> fetchNotifications() =>
      _firestoreReady
          ? FirestoreService.fetchNotifications()
          : _getList('/api/notifications');

  static Future<bool> upsertNotification(Map<String, dynamic> notif) =>
      _firestoreReady
          ? FirestoreService.upsertNotification(notif)
          : _post('/api/notifications', notif);

  static Future<bool> bulkSaveNotifications(
          List<Map<String, dynamic>> list) =>
      _firestoreReady
          ? FirestoreService.bulkSaveNotifications(list)
          : _post('/api/notifications/bulk', list);

  // ─────────────────────────────────────────────────────────────────────────
  // TICKETS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> fetchTickets({
    String? employeeId,
  }) async {
    if (_firestoreReady) {
      return FirestoreService.fetchTickets(employeeId: employeeId);
    }
    final endpoint = employeeId != null
        ? '/api/tickets?employee_id=$employeeId'
        : '/api/tickets';
    return _getList(endpoint);
  }

  static Future<bool> upsertTicket(Map<String, dynamic> ticket) =>
      _firestoreReady
          ? FirestoreService.upsertTicket(ticket)
          : _post('/api/tickets', ticket);

  static Future<bool> adminReplyTicket({
    required String ticketId,
    required String reply,
    required String repliedBy,
    required String newStatus,
    Map<String, dynamic>? message,
  }) =>
      _firestoreReady
          ? FirestoreService.adminReplyTicket(
              ticketId: ticketId,
              reply: reply,
              repliedBy: repliedBy,
              newStatus: newStatus,
              message: message,
            )
          : _post('/api/tickets/reply', {
              'ticket_id': ticketId,
              'reply': reply,
              'replied_by': repliedBy,
              'status': newStatus,
              if (message != null) 'message': message,
            });

  static Future<bool> updateTicketStatus({
    required String ticketId,
    required String status,
    String? resolvedAt,
  }) =>
      _firestoreReady
          ? FirestoreService.updateTicketStatus(
              ticketId: ticketId,
              status: status,
              resolvedAt: resolvedAt,
            )
          : _post('/api/tickets/status', {
              'ticket_id': ticketId,
              'status': status,
              if (resolvedAt != null) 'resolved_at': resolvedAt,
            });

  // ─────────────────────────────────────────────────────────────────────────
  // AUDIT LOGS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> fetchAuditLogs({
    String? employeeId,
  }) async {
    if (_firestoreReady) {
      return FirestoreService.fetchAuditLogs(employeeId: employeeId);
    }
    final endpoint = employeeId != null
        ? '/api/audit?employee_id=$employeeId'
        : '/api/audit';
    return _getList(endpoint);
  }

  static Future<bool> appendAuditLog(Map<String, dynamic> entry) =>
      _firestoreReady
          ? FirestoreService.appendAuditLog(entry)
          : _post('/api/audit', entry);
}
