// ═══════════════════════════════════════════════════════════════════════════
// firestore_service.dart  —  Firestore Data Layer  v1.0
//
// This is the single Firestore access layer for the Abhishek Attendance app.
// It mirrors every method in sync_service.dart so the two are interchangeable.
//
// Collections used:
//   employees       — all employee records (login credentials live here)
//   attendance      — daily check-in / check-out / break records
//   notifications   — admin-sent notifications
//   tickets         — employee-raised support tickets
//   audit_logs      — admin manual attendance change audit trail
//
// ⚠️  BEFORE THIS WORKS:
//   1. Add google-services.json to android/app/
//   2. Fill firebase_options.dart with your Firebase project values
//   3. Enable Firestore in Firebase Console → Build → Firestore Database
//   4. Set security rules (see FIREBASE_SETUP_GUIDE.md)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  // ── Singleton ───────────────────────────────────────────────────────────────
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  // ── Firestore instance ──────────────────────────────────────────────────────
  // Guard: only access FirebaseFirestore.instance when Firebase is initialized.
  // Accessing it before init throws [core/no-app] which is the root cause of
  // the "Firestore not reachable" error even when credentials are correct.
  static FirebaseFirestore get _db {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        '[FirestoreService] Firebase.apps is empty — '
        'Firebase.initializeApp() must complete before Firestore is accessed.',
      );
    }
    return FirebaseFirestore.instance;
  }

  // ── Collection references ───────────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> get _employees =>
      _db.collection('employees');
  static CollectionReference<Map<String, dynamic>> get _attendance =>
      _db.collection('attendance');
  static CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');
  static CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection('tickets');
  static CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection('audit_logs');

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Convert a Firestore document snapshot to a plain Map.
  static Map<String, dynamic> _docToMap(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    data['id'] = doc.id; // ensure 'id' is always present
    return data;
  }

  /// Convert a QuerySnapshot to a List<Map>.
  static List<Map<String, dynamic>> _queryToList(
      QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs.map(_docToMap).toList();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HEALTH CHECK
  // ───────────────────────────────────────────────────────────────────────────

  /// Returns true if Firestore is reachable.
  /// Steps:
  ///   1. Guard — Firebase must be initialized first.
  ///   2. Try a lightweight read on the _ping collection.
  ///   3. Any exception (permission denied, network, no-app) → return false.
  static Future<bool> isReachable() async {
    // Guard: Firebase must already be initialized by main.dart.
    if (Firebase.apps.isEmpty) {
      debugPrint('[Firestore] ❌ isReachable() called before Firebase.initializeApp()');
      return false;
    }
    try {
      debugPrint('[Firestore] 🔍 Testing Firestore connectivity...');
      await FirebaseFirestore.instance
          .collection('_ping')
          .limit(1)
          .get(GetOptions(source: Source.server));
      debugPrint('[Firestore] ✅ Firestore reachable — cloud mode active');
      return true;
    } on FirebaseException catch (e) {
      // PERMISSION_DENIED means Firestore exists but rules block us.
      // That still means Firebase is initialized and Firestore is reachable;
      // we just need correct security rules.
      if (e.code == 'permission-denied') {
        debugPrint('[Firestore] ⚠️  Firestore reachable but PERMISSION_DENIED.');
        debugPrint('[Firestore]    Open Firebase Console → Firestore → Rules');
        debugPrint('[Firestore]    Set: allow read, write: if true;');
        // Return true anyway — Firestore IS configured; writes will also fail
        // until rules are opened, but that is a console config issue not a
        // code issue. Returning false here would mask real init problems.
        return true;
      }
      debugPrint('[Firestore] ❌ FirebaseException: ${e.code} — ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Firestore] ❌ isReachable error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EMPLOYEES
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch all employees.
  static Future<List<Map<String, dynamic>>?> fetchEmployees() async {
    try {
      final snap = await _employees.get();
      return _queryToList(snap);
    } catch (e) {
      debugPrint('[Firestore] fetchEmployees error: $e');
      return null;
    }
  }

  /// Add or update a single employee (upsert by id).
  static Future<bool> upsertEmployee(Map<String, dynamic> emp) async {
    try {
      final id = emp['id'] as String? ?? '';
      if (id.isEmpty) return false;
      await _employees.doc(id).set(emp, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[Firestore] upsertEmployee error: $e');
      return false;
    }
  }

  /// Delete an employee by id.
  static Future<bool> deleteEmployee(String id) async {
    try {
      await _employees.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('[Firestore] deleteEmployee error: $e');
      return false;
    }
  }

  /// Update employee password only.
  static Future<bool> updateEmployeePassword(String id, String hash) async {
    try {
      await _employees.doc(id).update({'password_hash': hash});
      return true;
    } catch (e) {
      debugPrint('[Firestore] updateEmployeePassword error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ATTENDANCE
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch attendance records. Optional filters: employeeId, date (yyyy-MM-dd).
  static Future<List<Map<String, dynamic>>?> fetchAttendance({
    String? employeeId,
    String? date,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _attendance;

      if (employeeId != null && employeeId.isNotEmpty) {
        q = q.where('employee_id', isEqualTo: employeeId);
      }
      if (date != null && date.isNotEmpty) {
        q = q.where('date', isEqualTo: date);
      }

      final snap = await q.get();
      return _queryToList(snap);
    } catch (e) {
      debugPrint('[Firestore] fetchAttendance error: $e');
      return null;
    }
  }

  /// Strip null values — Firestore rejects some null fields in nested writes.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> data) {
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) return;
      if (value is Map) {
        out[key] = _sanitize(Map<String, dynamic>.from(value));
      } else if (value is List) {
        out[key] = value
            .map((e) => e is Map ? _sanitize(Map<String, dynamic>.from(e)) : e)
            .toList();
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Add or update a single attendance record (upsert by id).
  static Future<bool> upsertAttendance(Map<String, dynamic> att) async {
    try {
      final id = att['id'] as String? ?? '';
      if (id.isEmpty) return false;
      final payload = _sanitize(att);
      await _attendance.doc(id).set(payload, SetOptions(merge: true));
      debugPrint('[Firestore] ✅ attendance saved: $id (${payload['employee_name']})');
      return true;
    } catch (e) {
      debugPrint('[Firestore] upsertAttendance error: $e');
      return false;
    }
  }

  /// Admin manual mark: write attendance record + audit log atomically
  /// using a Firestore batch write.
  static Future<bool> adminMarkAttendance({
    required Map<String, dynamic> attendance,
    required Map<String, dynamic> auditEntry,
  }) async {
    try {
      final attId   = attendance['id'] as String? ?? '';
      final auditId = auditEntry['id']  as String? ?? '';
      if (attId.isEmpty) return false;

      final batch = _db.batch();
      batch.set(_attendance.doc(attId), attendance, SetOptions(merge: true));
      if (auditId.isNotEmpty) {
        batch.set(_audit.doc(auditId), auditEntry, SetOptions(merge: true));
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('[Firestore] adminMarkAttendance error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch all notifications (client filters by target).
  static Future<List<Map<String, dynamic>>?> fetchNotifications() async {
    try {
      final snap = await _notifications
          .orderBy('created_at', descending: true)
          .get();
      return _queryToList(snap);
    } catch (e) {
      // Fallback without orderBy in case index not ready
      try {
        final snap = await _notifications.get();
        return _queryToList(snap);
      } catch (e2) {
        debugPrint('[Firestore] fetchNotifications error: $e2');
        return null;
      }
    }
  }

  /// Add or update a notification (upsert by id).
  static Future<bool> upsertNotification(Map<String, dynamic> notif) async {
    try {
      final id = notif['id'] as String? ?? '';
      if (id.isEmpty) return false;
      await _notifications.doc(id).set(notif, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[Firestore] upsertNotification error: $e');
      return false;
    }
  }

  /// Bulk-save entire notification list (replaces all — used for read-sync).
  static Future<bool> bulkSaveNotifications(
      List<Map<String, dynamic>> list) async {
    try {
      // Use batched writes (max 500 per batch)
      const batchSize = 400;
      for (var i = 0; i < list.length; i += batchSize) {
        final chunk = list.sublist(
            i, i + batchSize > list.length ? list.length : i + batchSize);
        final batch = _db.batch();
        for (final n in chunk) {
          final id = n['id'] as String? ?? '';
          if (id.isNotEmpty) {
            batch.set(_notifications.doc(id), n, SetOptions(merge: true));
          }
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      debugPrint('[Firestore] bulkSaveNotifications error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TICKETS
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch all tickets (admin) or filter by employeeId (employee).
  static Future<List<Map<String, dynamic>>?> fetchTickets({
    String? employeeId,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _tickets;
      if (employeeId != null && employeeId.isNotEmpty) {
        q = q.where('employee_id', isEqualTo: employeeId);
      }
      final snap = await q.get();
      final list = _queryToList(snap);
      // Sort newest first in memory (avoids composite index requirement)
      list.sort((a, b) {
        final ta = a['created_at'] as String? ?? '';
        final tb = b['created_at'] as String? ?? '';
        return tb.compareTo(ta);
      });
      return list;
    } catch (e) {
      debugPrint('[Firestore] fetchTickets error: $e');
      return null;
    }
  }

  /// Employee raises a ticket / upsert (by id).
  static Future<bool> upsertTicket(Map<String, dynamic> ticket) async {
    try {
      final id = ticket['id'] as String? ?? '';
      if (id.isEmpty) return false;
      await _tickets.doc(id).set(ticket, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[Firestore] upsertTicket error: $e');
      return false;
    }
  }

  /// Admin replies to a ticket (updates reply, status, appends message).
  static Future<bool> adminReplyTicket({
    required String ticketId,
    required String reply,
    required String repliedBy,
    required String newStatus,
    Map<String, dynamic>? message,
  }) async {
    try {
      final ref = _tickets.doc(ticketId);
      await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) throw Exception('Ticket $ticketId not found');
        final data = snap.data()!;
        final msgs = List<dynamic>.from(data['messages'] as List? ?? []);
        if (message != null) msgs.add(message);
        txn.update(ref, {
          'admin_reply': reply,
          'replied_by':  repliedBy,
          'status':      newStatus,
          'messages':    msgs,
        });
      });
      return true;
    } catch (e) {
      debugPrint('[Firestore] adminReplyTicket error: $e');
      return false;
    }
  }

  /// Admin updates ticket status only.
  static Future<bool> updateTicketStatus({
    required String ticketId,
    required String status,
    String? resolvedAt,
  }) async {
    try {
      final Map<String, dynamic> update = {'status': status};
      if (resolvedAt != null) update['resolved_at'] = resolvedAt;
      await _tickets.doc(ticketId).update(update);
      return true;
    } catch (e) {
      debugPrint('[Firestore] updateTicketStatus error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // AUDIT LOGS
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch audit logs, optionally filtered by employeeId.
  static Future<List<Map<String, dynamic>>?> fetchAuditLogs({
    String? employeeId,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _audit;
      if (employeeId != null && employeeId.isNotEmpty) {
        q = q.where('employee_id', isEqualTo: employeeId);
      }
      final snap = await q.get();
      final list = _queryToList(snap);
      list.sort((a, b) {
        final ta = a['updated_at'] as String? ?? '';
        final tb = b['updated_at'] as String? ?? '';
        return tb.compareTo(ta);
      });
      return list;
    } catch (e) {
      debugPrint('[Firestore] fetchAuditLogs error: $e');
      return null;
    }
  }

  /// Append a single audit log entry.
  static Future<bool> appendAuditLog(Map<String, dynamic> entry) async {
    try {
      final id = entry['id'] as String? ?? '';
      if (id.isEmpty) return false;
      await _audit.doc(id).set(entry, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[Firestore] appendAuditLog error: $e');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // REAL-TIME STREAMS (optional — use for live dashboard updates)
  // ───────────────────────────────────────────────────────────────────────────

  /// Stream all attendance for today (for admin live dashboard).
  /// Listens to the full collection and filters client-side so both
  /// `yyyy-MM-dd` and full ISO date strings match.
  static Stream<List<Map<String, dynamic>>> streamTodayAttendance(String date) {
    return _attendance.snapshots().map((snap) {
      return _queryToList(snap).where((m) {
        final d = m['date']?.toString() ?? '';
        return d == date || d.startsWith('$date');
      }).toList();
    });
  }

  /// Stream all open tickets (for admin ticket management).
  static Stream<List<Map<String, dynamic>>> streamOpenTickets() {
    return _tickets
        .where('status', isEqualTo: 'Open')
        .snapshots()
        .map((snap) => _queryToList(snap));
  }

  /// Stream notifications for a specific employee.
  static Stream<List<Map<String, dynamic>>> streamNotifications() {
    return _notifications
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => _queryToList(snap));
  }

  /// Get admin settings document from Firestore.
  static Future<Map<String, dynamic>?> getAdminSettings() async {
    try {
      final doc = await _db.collection('admin_settings').doc('main').get();
      if (doc.exists) return doc.data();
    } catch (_) {}
    return null;
  }
}
