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
//
// For FOREGROUND: FcmService.setupForegroundHandler() → shows local notif
// For BACKGROUND/KILLED: OS shows it automatically from notification{} block
//   Background isolate also runs to handle data-only messages as backup
// ─────────────────────────────────────────────────────────────────────────────

// ── BACKGROUND HANDLER — top-level, runs in separate Dart isolate ─────────────
// This is the MOST CRITICAL function for background/killed state notifications.
// The OS will show the notification from the FCM notification{} block,
// but this handler also shows it via flutter_local_notifications as a backup.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Step 1: Initialize Flutter bindings in this fresh isolate
  // (not needed for newer flutter_local_notifications but safe to have)

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

  if (kDebugMode) {
    debugPrint('[FCM BG] ✅ Shown background notification: "$title"');
  }
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

  // ── Request permission + get FCM token ────────────────────────────────────
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) debugPrint('[FCM] Permission DENIED');
        return null;
      }

      // Tell FCM to also show notification when app is in foreground
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _fcm.getToken();
      if (kDebugMode) debugPrint('[FCM] Token obtained: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // ── Save FCM token to Firestore ───────────────────────────────────────────
  static Future<void> saveTokenToFirestore({
    required String employeeId,
    required String token,
  }) async {
    if (token.isEmpty || employeeId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .update({'fcm_token': token});
      if (kDebugMode) debugPrint('[FCM] Token saved for $employeeId');
    } catch (_) {
      try {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)
            .set({'fcm_token': token}, SetOptions(merge: true));
      } catch (e2) {
        if (kDebugMode) debugPrint('[FCM] saveToken fallback error: $e2');
      }
    }
  }

  // ── Foreground handler — shows heads-up banner via local notifications ────
  // Called from main.dart AFTER Firebase.initializeApp()
  static void setupForegroundHandler({void Function(RemoteMessage)? onMessage}) {
    if (kIsWeb) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] FOREGROUND: "${message.notification?.title}" '
            'type=${message.data["type"]}');
      }
      // Show as heads-up banner — OS won't do this automatically for foreground
      LocalNotificationService.showFromRemoteMessage(message);
      onMessage?.call(message);
    });
  }

  // ── Handle notification tap when app was in background (not killed) ───────
  static void setupNotificationOpenHandler({void Function(RemoteMessage)? onOpen}) {
    if (kIsWeb) return;
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) debugPrint('[FCM] Opened from notification: ${message.notification?.title}');
      onOpen?.call(message);
    });
  }

  // ── Get message that launched app from killed state ───────────────────────
  static Future<RemoteMessage?> getInitialMessage() async {
    if (kIsWeb) return null;
    return await _fcm.getInitialMessage();
  }

  // ── Collect tokens for target audience ───────────────────────────────────
  static Future<List<String>> _getTargetTokens({
    required String targetType,
    required String targetValue,
    required List<Map<String, dynamic>> allEmployees,
  }) async {
    List<Map<String, dynamic>> targets;
    switch (targetType) {
      case 'global':
      case 'all':
        targets = allEmployees;
        break;
      case 'company':
        targets = allEmployees.where((e) =>
            e['company_id'] == targetValue || e['company_name'] == targetValue).toList();
        break;
      case 'department':
        targets = allEmployees.where((e) => e['department'] == targetValue).toList();
        break;
      case 'shift':
        targets = allEmployees.where((e) => e['shift_type'] == targetValue).toList();
        break;
      case 'individual':
      case 'employee':
        targets = allEmployees.where((e) => e['id'] == targetValue).toList();
        break;
      default:
        targets = [];
    }
    return targets
        .map((e) => (e['fcm_token'] as String?) ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ── Write to fcm_send_queue → Cloud Function picks up instantly ───────────
  static Future<void> sendPushToTargets({
    required String title,
    required String message,
    required String targetType,
    required String targetValue,
    required List<Map<String, dynamic>> allEmployees,
    String priority = 'Normal',
  }) async {
    if (kIsWeb) return;
    try {
      final tokens = await _getTargetTokens(
        targetType: targetType,
        targetValue: targetValue,
        allEmployees: allEmployees,
      );
      if (tokens.isEmpty) {
        if (kDebugMode) debugPrint('[FCM] No tokens for $targetType:$targetValue');
        return;
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
      if (kDebugMode) debugPrint('[FCM] Queued to ${tokens.length} tokens');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] sendPushToTargets error: $e');
    }
  }

  static String encodeTokenList(List<String> tokens) => jsonEncode(tokens);
  static List<String> decodeTokenList(String encoded) {
    try { return List<String>.from(jsonDecode(encoded) as List); }
    catch (_) { return []; }
  }
}
