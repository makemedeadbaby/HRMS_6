import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM Service
//
// Notification display strategy:
//
//  ┌─────────────────┬──────────────────────────────────────────────────────┐
//  │ App state       │ How notification shows                               │
//  ├─────────────────┼──────────────────────────────────────────────────────┤
//  │ FOREGROUND      │ FCM onMessage → LocalNotificationService.show()      │
//  │                 │ (OS won't auto-show when app is open)                │
//  ├─────────────────┼──────────────────────────────────────────────────────┤
//  │ BACKGROUND      │ FCM delivers to background isolate                   │
//  │ (minimized)     │ If msg has notification{} block → OS shows it        │
//  │                 │ If data-only → background handler calls show()       │
//  ├─────────────────┼──────────────────────────────────────────────────────┤
//  │ KILLED          │ OS delivers notification directly using the channel  │
//  │ (swiped away)   │ declared in AndroidManifest meta-data               │
//  │                 │ No Flutter code runs — OS handles it completely      │
//  └─────────────────┴──────────────────────────────────────────────────────┘
//
//  Cloud Functions ALWAYS send messages with BOTH notification{} + data{}
//  so the OS can display them even when the app is fully killed.
// ─────────────────────────────────────────────────────────────────────────────

class FcmService {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  // ── Request permission + return device token ──────────────────────────────
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      if (kDebugMode) {
        debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      // Critical: tell FCM to show notification even when app is foreground
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _fcm.getToken();
      if (kDebugMode) debugPrint('[FCM] Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // ── Save / refresh FCM token in Firestore ─────────────────────────────────
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
        if (kDebugMode) debugPrint('[FCM] saveToken error: $e2');
      }
    }
  }

  // ── Register background message handler ──────────────────────────────────
  // MUST be called before runApp() — before Firebase.initializeApp() even.
  static void setupBackgroundHandler() {
    if (kIsWeb) return;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ── Foreground handler — show heads-up banner via local notifications ─────
  static void setupForegroundHandler({
    void Function(RemoteMessage)? onMessage,
  }) {
    if (kIsWeb) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] FOREGROUND message: '
            '${message.notification?.title} | type=${message.data["type"]}');
      }

      // Show the notification as a heads-up banner
      LocalNotificationService.showFromRemoteMessage(message);

      // Call any extra handler (e.g. refresh UI)
      onMessage?.call(message);
    });
  }

  // ── Handle notification tap (app in background, not killed) ──────────────
  static void setupNotificationOpenHandler({
    void Function(RemoteMessage)? onOpen,
  }) {
    if (kIsWeb) return;
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Notification tapped: ${message.notification?.title}');
      }
      onOpen?.call(message);
    });
  }

  // ── Check if app was launched FROM a notification tap (killed state) ──────
  static Future<RemoteMessage?> getInitialMessage() async {
    if (kIsWeb) return null;
    return await _fcm.getInitialMessage();
  }

  // ── Collect FCM tokens for target audience ────────────────────────────────
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
        targets = allEmployees
            .where((e) =>
                e['company_id'] == targetValue ||
                e['company_name'] == targetValue)
            .toList();
        break;
      case 'department':
        targets =
            allEmployees.where((e) => e['department'] == targetValue).toList();
        break;
      case 'shift':
        targets =
            allEmployees.where((e) => e['shift_type'] == targetValue).toList();
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

  // ── Send push notification via Firestore queue (processed by Cloud Fn) ────
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
        if (kDebugMode) {
          debugPrint('[FCM] No tokens for $targetType:$targetValue');
        }
        return;
      }

      // Write to fcm_send_queue — Cloud Function processes instantly
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

      if (kDebugMode) {
        debugPrint('[FCM] Queued push to ${tokens.length} devices');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] sendPushToTargets error: $e');
    }
  }

  static String encodeTokenList(List<String> tokens) => jsonEncode(tokens);
  static List<String> decodeTokenList(String encoded) {
    try {
      return List<String>.from(jsonDecode(encoded) as List);
    } catch (_) {
      return [];
    }
  }
}

// ── Top-level background handler ──────────────────────────────────────────────
// Runs in a SEPARATE ISOLATE when app is in background but NOT killed.
// Must be a top-level function (not a class method).
// Firebase is auto-initialized by FlutterFire before this runs.
//
// IMPORTANT: For killed state, the OS handles the notification display
// automatically using the notification{} block in the FCM payload.
// This handler only fires for data-only messages in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize local notifications in this isolate for data-only messages
  await LocalNotificationService.init();
  await LocalNotificationService.showFromRemoteMessage(message);

  if (kDebugMode) {
    debugPrint('[FCM Background] Showed: ${message.notification?.title ?? message.data["title"]}');
  }
}
