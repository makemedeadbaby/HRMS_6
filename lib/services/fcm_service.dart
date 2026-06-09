import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'local_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM Service + Background Handler
//
// CRITICAL RULES for the background handler:
//   1. Must be a TOP-LEVEL function (not inside a class)
//   2. Must call Firebase.initializeApp() itself — it runs in a FRESH isolate
//   3. Must create its OWN FlutterLocalNotificationsPlugin instance
//   4. @pragma('vm:entry-point') annotation is REQUIRED
// ─────────────────────────────────────────────────────────────────────────────

// ── BACKGROUND HANDLER — top-level, runs in separate Dart isolate ─────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Step 2: Initialize Firebase in THIS isolate
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Step 3: Create a fresh plugin instance — static vars don't carry over
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  // Step 4: Extract title + body from either notification{} or data{}
  final title = message.notification?.title
      ?? message.data['title'] as String?
      ?? 'Abhishek HRMS';
  final body  = message.notification?.body
      ?? message.data['body'] as String?
      ?? '';
  final type  = (message.data['type'] as String?) ?? 'custom';

  if (title.isEmpty && body.isEmpty) return;

  // Step 5: Map type to correct channel ID
  String channelId;
  String channelName;
  switch (type) {
    case 'break_end':
      channelId   = kBreakChannelId;
      channelName = 'Break Reminders';
      break;
    case 'logout_reminder':
    case 'shift_reminder':
      channelId   = kReminderChannelId;
      channelName = 'Shift Reminders';
      break;
    default:
      channelId   = kAdminChannelId;
      channelName = 'Admin Notifications';
  }

  // Step 6: Show the notification
  final notifId = (message.data['notification_id'] ?? title).hashCode.abs() % 100000;
  await plugin.show(
    notifId,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
        icon: '@mipmap/ic_launcher',
        ticker: title,
      ),
    ),
    payload: type,
  );

  debugPrint('[FCM BG] ✅ Shown background notification: "$title"');
}

// ─────────────────────────────────────────────────────────────────────────────
// FcmService — manages FCM token + foreground notifications
// ─────────────────────────────────────────────────────────────────────────────
class FcmService {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  // ── Register background handler (call BEFORE Firebase.initializeApp) ──────
  static void setupBackgroundHandler() {
    if (kIsWeb) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ── Listen for token refresh events ──────────────────────────────────────
  // This fires when FCM rotates the token (network change, app reinstall, etc.)
  // MUST be called after Firebase.initializeApp()
  static void setupTokenRefreshHandler({
    required void Function(String token) onRefresh,
  }) {
    if (kIsWeb) return;
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] 🔄 Token refreshed: ${newToken.substring(0, 20)}...');
      onRefresh(newToken);
    });
  }

  // ── Request permission + get FCM token ────────────────────────────────────
  // Returns the token string, or null if permission denied / unavailable.
  // Logs every step so we can diagnose failures.
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      debugPrint('[FCM] Requesting notification permission...');
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ❌ Permission DENIED by user — notifications will not work');
        debugPrint('[FCM]    → Tell user to go to Settings > Apps > Abhishek Attendance > Notifications');
        return null;
      }

      // Tell FCM to show notification when app is in foreground (iOS)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('[FCM] Calling getToken()...');
      final token = await _fcm.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] ❌ getToken() returned null/empty — '
            'possible causes: no internet, Google Play Services issue, '
            'or Firebase project misconfiguration');
        return null;
      }

      debugPrint('[FCM] ✅ Token obtained: ${token.substring(0, 30)}...');
      return token;
    } catch (e, stack) {
      debugPrint('[FCM] ❌ getToken() exception: $e');
      debugPrint('[FCM]    Stack: $stack');
      return null;
    }
  }

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  // Uses both update() and set(merge:true) fallback.
  // Also logs success/failure explicitly.
  static Future<bool> saveTokenToFirestore({
    required String employeeId,
    required String token,
  }) async {
    if (token.isEmpty || employeeId.isEmpty) {
      debugPrint('[FCM] saveTokenToFirestore: skipped — '
          'token.isEmpty=${token.isEmpty} employeeId.isEmpty=${employeeId.isEmpty}');
      return false;
    }
    debugPrint('[FCM] Saving token to Firestore for employee: $employeeId');
    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .update({'fcm_token': token});
      debugPrint('[FCM] ✅ Token saved (update) for $employeeId');
      return true;
    } catch (e1) {
      debugPrint('[FCM] update() failed ($e1), trying set(merge:true)...');
      try {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)
            .set({'fcm_token': token}, SetOptions(merge: true));
        debugPrint('[FCM] ✅ Token saved (set/merge) for $employeeId');
        return true;
      } catch (e2) {
        debugPrint('[FCM] ❌ saveTokenToFirestore FAILED for $employeeId: $e2');
        return false;
      }
    }
  }

  // ── Foreground handler — shows heads-up banner via local notifications ────
  static void setupForegroundHandler({void Function(RemoteMessage)? onMessage}) {
    if (kIsWeb) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] FOREGROUND message: '
          'title="${message.notification?.title}" '
          'type=${message.data["type"]} '
          'data=${message.data}');
      // Show as heads-up banner — OS won't do this automatically for foreground
      LocalNotificationService.showFromRemoteMessage(message);
      onMessage?.call(message);
    });
  }

  // ── Handle notification tap when app was in background (not killed) ───────
  static void setupNotificationOpenHandler({void Function(RemoteMessage)? onOpen}) {
    if (kIsWeb) return;
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Opened from notification: ${message.notification?.title}');
      onOpen?.call(message);
    });
  }

  // ── Get message that launched app from killed state ───────────────────────
  static Future<RemoteMessage?> getInitialMessage() async {
    if (kIsWeb) return null;
    return await _fcm.getInitialMessage();
  }


  // ── Fetch FCM tokens fresh from Firestore for a target audience ──────────
  // Reads directly from Firestore so we always get the latest tokens,
  // even if the in-memory employee list has stale/empty fcmToken values.
  static Future<List<String>> _getTokensFromFirestore({
    required String targetType,
    required String targetValue,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          FirebaseFirestore.instance.collection('employees');

      // Apply filter based on target type
      switch (targetType.toLowerCase()) {
        case 'company':
          query = query.where('company_name', isEqualTo: targetValue);
          break;
        case 'department':
          query = query.where('department', isEqualTo: targetValue);
          break;
        case 'shift':
          query = query.where('shift_type', isEqualTo: targetValue);
          break;
        case 'individual':
        case 'employee':
          // targetValue is the employee doc ID
          final doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(targetValue)
              .get();
          if (doc.exists) {
            final d = doc.data()!;
            final t = (d['fcm_token'] as String?) ??
                (d['fcmToken'] as String?) ?? '';
            return t.isNotEmpty ? [t] : [];
          }
          return [];
        case 'global':
        case 'all':
        default:
          break; // no filter — all employees
      }

      final snap = await query.get();
      final tokens = <String>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final t = (d['fcm_token'] as String?) ??
            (d['fcmToken'] as String?) ?? '';
        if (t.isNotEmpty) tokens.add(t);
      }
      debugPrint('[FCM] _getTokensFromFirestore: found ${tokens.length} tokens '
          'for $targetType:$targetValue');
      return tokens;
    } catch (e) {
      debugPrint('[FCM] _getTokensFromFirestore error: $e');
      return [];
    }
  }

  // ── Write to fcm_send_queue → Cloud Function picks up instantly ───────────
  // Works on BOTH web (admin portal) and Android (employee app).
  // The Cloud Function processFcmSendQueue fires on Firestore write regardless
  // of which platform created the document.
  static Future<void> sendPushToTargets({
    required String title,
    required String message,
    required String targetType,
    required String targetValue,
    required List<Map<String, dynamic>> allEmployees,
    String priority = 'Normal',
  }) async {
    try {
      // Always fetch tokens fresh from Firestore — in-memory list may be stale
      final tokens = await _getTokensFromFirestore(
        targetType: targetType,
        targetValue: targetValue,
      );

      if (tokens.isEmpty) {
        debugPrint('[FCM] ⚠️  No FCM tokens found for $targetType:$targetValue — '
            'employees may not have logged in yet to register tokens');
        // Still write the queue doc — Cloud Function will log the failure
        // and the admin can retry once employees have registered
      }

      await FirebaseFirestore.instance.collection('fcm_send_queue').add({
        'title': title,
        'body': message,
        'priority': priority.toLowerCase(),
        'target_type': targetType,
        'target_value': targetValue,
        'tokens': tokens,
        'sent_at': FieldValue.serverTimestamp(),
        'processed': false,
      });
      debugPrint('[FCM] ✅ Queued notification to ${tokens.length} device(s)');
    } catch (e) {
      debugPrint('[FCM] ❌ sendPushToTargets error: $e');
    }
  }

  static String encodeTokenList(List<String> tokens) => jsonEncode(tokens);
  static List<String> decodeTokenList(String encoded) {
    try { return List<String>.from(jsonDecode(encoded) as List); }
    catch (_) { return []; }
  }
}
