import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationScheduler — handles scheduled push notifications for:
//   1. Break timer — countdown when employee starts break; FCM push at end
//   2. Logout reminder — 1 hour before shift end, sends FCM push
//   3. Shift start reminder — 15 mins before shift starts
//
// Architecture:
//   • Uses Firestore `scheduled_notifications` collection as a queue
//   • A Cloud Function (or a local periodic timer) processes the queue
//   • Falls back to local in-app countdown when no Cloud Function is deployed
//
// The `scheduled_notifications` collection document structure:
//   {
//     employee_id: string,
//     fcm_token: string,
//     title: string,
//     body: string,
//     scheduled_at: Timestamp,   // when to fire
//     type: string,              // 'break_end' | 'logout_reminder' | 'shift_reminder'
//     processed: bool,
//     created_at: Timestamp,
//   }
// ─────────────────────────────────────────────────────────────────────────────

class NotificationScheduler {
  static final _db = FirebaseFirestore.instance;

  // ── Active break timer ─────────────────────────────────────────────────────
  static Timer? _breakTimer;
  static DateTime? _breakStartTime;
  static StreamController<Duration>? _breakStreamCtrl;

  // Stream of elapsed break duration (updated every second)
  static Stream<Duration> get breakElapsedStream {
    _breakStreamCtrl ??= StreamController<Duration>.broadcast();
    return _breakStreamCtrl!.stream;
  }

  // ── Start break timer + schedule FCM push ─────────────────────────────────
  static Future<void> startBreakTimer({
    required String employeeId,
    required String fcmToken,
    int maxBreakMinutes = 30,
  }) async {
    _breakStartTime = DateTime.now();
    _breakStreamCtrl ??= StreamController<Duration>.broadcast();

    // Tick every second to update the live elapsed counter
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_breakStartTime == null) return;
      final elapsed = DateTime.now().difference(_breakStartTime!);
      _breakStreamCtrl?.add(elapsed);
    });

    if (kIsWeb) return; // FCM push not available on web

    // Schedule Firestore notification for when max break time ends
    final fireAt = DateTime.now().add(Duration(minutes: maxBreakMinutes));
    await _scheduleNotification(
      employeeId: employeeId,
      fcmToken: fcmToken,
      title: '⏰ Break Time Over!',
      body: 'Your $maxBreakMinutes-minute break has ended. Time to get back to work!',
      scheduledAt: fireAt,
      type: 'break_end',
    );

    if (kDebugMode) {
      debugPrint('[NotificationScheduler] Break timer started — push at $fireAt');
    }
  }

  // ── Stop break timer ───────────────────────────────────────────────────────
  static Future<void> stopBreakTimer({
    required String employeeId,
  }) async {
    _breakTimer?.cancel();
    _breakTimer = null;
    _breakStartTime = null;
    _breakStreamCtrl?.add(Duration.zero);

    // Cancel pending break_end notification for this employee
    if (!kIsWeb) {
      await _cancelPendingNotifications(
        employeeId: employeeId,
        type: 'break_end',
      );
    }

    if (kDebugMode) debugPrint('[NotificationScheduler] Break timer stopped');
  }

  // ── Get current break elapsed time ────────────────────────────────────────
  static Duration get currentBreakElapsed {
    if (_breakStartTime == null) return Duration.zero;
    return DateTime.now().difference(_breakStartTime!);
  }

  static bool get isBreakTimerActive => _breakTimer?.isActive == true;

  // ── Schedule logout reminder (1 hour before shift end) ────────────────────
  static Future<void> scheduleLogoutReminder({
    required String employeeId,
    required String fcmToken,
    required String shiftEndTime, // e.g. "06:30 PM"
  }) async {
    if (kIsWeb) return;

    try {
      final endDt = _parseShiftTime(shiftEndTime);
      if (endDt == null) return;

      final reminderAt = endDt.subtract(const Duration(hours: 1));
      if (reminderAt.isBefore(DateTime.now())) return; // already passed

      await _scheduleNotification(
        employeeId: employeeId,
        fcmToken: fcmToken,
        title: '🕐 1 Hour Left to Check Out',
        body: 'Your shift ends at $shiftEndTime. Remember to check out before leaving.',
        scheduledAt: reminderAt,
        type: 'logout_reminder',
      );

      if (kDebugMode) {
        debugPrint('[NotificationScheduler] Logout reminder scheduled for $reminderAt');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationScheduler] scheduleLogoutReminder error: $e');
    }
  }

  // ── Schedule shift start reminder (15 mins before shift) ──────────────────
  static Future<void> scheduleShiftReminder({
    required String employeeId,
    required String fcmToken,
    required String shiftStartTime, // e.g. "09:30 AM"
    required String shiftType,
  }) async {
    if (kIsWeb) return;

    try {
      final startDt = _parseShiftTime(shiftStartTime);
      if (startDt == null) return;

      final reminderAt = startDt.subtract(const Duration(minutes: 15));
      if (reminderAt.isBefore(DateTime.now())) return;

      await _scheduleNotification(
        employeeId: employeeId,
        fcmToken: fcmToken,
        title: '🌅 Shift Starting Soon',
        body: 'Your $shiftType starts at $shiftStartTime. Time to get ready!',
        scheduledAt: reminderAt,
        type: 'shift_reminder',
      );

      if (kDebugMode) {
        debugPrint('[NotificationScheduler] Shift reminder scheduled for $reminderAt');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationScheduler] scheduleShiftReminder error: $e');
    }
  }

  // ── Write scheduled notification to Firestore queue ───────────────────────
  static Future<void> _scheduleNotification({
    required String employeeId,
    required String fcmToken,
    required String title,
    required String body,
    required DateTime scheduledAt,
    required String type,
  }) async {
    if (fcmToken.isEmpty || employeeId.isEmpty) return;

    try {
      // Remove any existing unprocessed notifications of same type for employee
      await _cancelPendingNotifications(employeeId: employeeId, type: type);

      await _db.collection('scheduled_notifications').add({
        'employee_id': employeeId,
        'fcm_token': fcmToken,
        'title': title,
        'body': body,
        'scheduled_at': Timestamp.fromDate(scheduledAt),
        'type': type,
        'processed': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationScheduler] _scheduleNotification error: $e');
      }
    }
  }

  // ── Cancel pending notifications of a specific type ───────────────────────
  static Future<void> _cancelPendingNotifications({
    required String employeeId,
    required String type,
  }) async {
    try {
      final snap = await _db
          .collection('scheduled_notifications')
          .where('employee_id', isEqualTo: employeeId)
          .where('type', isEqualTo: type)
          .where('processed', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      if (snap.docs.isNotEmpty) await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationScheduler] cancel error: $e');
      }
    }
  }

  // ── Parse shift time string e.g. "09:30 AM" to today's DateTime ──────────
  static DateTime? _parseShiftTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length < 2) return null;

      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts[1].toUpperCase() == 'PM';

      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // ── Subscribe to FCM foreground messages for scheduled types ──────────────
  // NOTE: FcmService.setupForegroundHandler() ALSO listens to onMessage and
  // calls LocalNotificationService.showFromRemoteMessage(). This handler only
  // adds the break-timer stop logic on top of that.
  static void setupForegroundScheduledHandler() {
    if (kIsWeb) return;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      final type = data['type'] as String?;

      if (kDebugMode) {
        debugPrint('[NotificationScheduler] Foreground FCM: '
            'type=$type title=${message.notification?.title}');
      }

      // Stop the in-app break timer if the Cloud Function fired break_end
      if (type == 'break_end') {
        stopBreakTimer(employeeId: data['employee_id'] ?? '');
      }
    });
  }

  // ── Show a local notification immediately (for in-app use) ────────────────
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String type = 'custom',
  }) async {
    await LocalNotificationService.showLocal(
      title: title,
      body: body,
      type: type,
    );
  }

  // ── Dispose ────────────────────────────────────────────────────────────────
  static void dispose() {
    _breakTimer?.cancel();
    _breakStreamCtrl?.close();
    _breakTimer = null;
    _breakStreamCtrl = null;
    _breakStartTime = null;
  }
}
