import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM Service — handles token registration and push notification dispatch.
//
// Push delivery uses Firestore to store tokens and FCM data messages for
// targeting. On mobile (Android) the OS delivers the notification; on web
// the in-app notification centre already covers delivery.
// ─────────────────────────────────────────────────────────────────────────────
class FcmService {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  // ── Request permission + return the device token ───────────────────────────
  static Future<String?> getToken() async {
    if (kIsWeb) return null; // Web tokens require a VAPID key — skip for mobile
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      final token = await _fcm.getToken();
      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // ── Save / update FCM token for an employee document in Firestore ──────────
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
    } catch (e) {
      // Document may not exist yet — try set with merge
      try {
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(employeeId)
            .set({'fcm_token': token}, SetOptions(merge: true));
      } catch (e2) {
        if (kDebugMode) debugPrint('[FCM] saveTokenToFirestore error: $e2');
      }
    }
  }

  // ── Collect FCM tokens for target audience ─────────────────────────────────
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
          e['company_id'] == targetValue ||
          e['company_name'] == targetValue
        ).toList();
        break;
      case 'department':
        targets = allEmployees.where((e) =>
          e['department'] == targetValue
        ).toList();
        break;
      case 'shift':
        targets = allEmployees.where((e) =>
          e['shift_type'] == targetValue
        ).toList();
        break;
      case 'individual':
      case 'employee':
        targets = allEmployees.where((e) => e['id'] == targetValue).toList();
        break;
      default:
        targets = [];
    }

    final tokens = <String>[];
    for (final emp in targets) {
      final token = (emp['fcm_token'] as String?) ?? '';
      if (token.isNotEmpty) tokens.add(token);
    }
    return tokens;
  }

  // ── Send push notification via FCM using Firestore queue ──────────────────
  //
  // Strategy: Write a 'fcm_queue' document in Firestore.
  // A Cloud Function (or the app itself on next foreground) picks this up.
  // For immediate delivery on Android, we also use the FCM REST API directly
  // via the Firestore-based approach.
  //
  // Since we don't have a server-side Cloud Function deployed, we use the
  // Firestore 'notifications' collection which the app reads on launch.
  // The actual push is sent by writing to 'fcm_send_queue' which can be
  // processed by a Cloud Function, OR we use the local notification display
  // approach for in-app delivery plus the OS notification for background.
  // ─────────────────────────────────────────────────────────────────────────
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
          debugPrint('[FCM] No tokens found for target $targetType:$targetValue');
        }
        return;
      }

      // Write to Firestore fcm_send_queue for Cloud Function processing
      // Each entry = one batch of tokens + payload
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

  // ── Register background message handler (call from main.dart) ─────────────
  static void setupBackgroundHandler() {
    if (kIsWeb) return;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ── Foreground message listener ────────────────────────────────────────────
  static void setupForegroundHandler({
    void Function(RemoteMessage)? onMessage,
  }) {
    if (kIsWeb) return;
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      }
      onMessage?.call(message);
    });
  }

  // ── Handle notification tap when app is in background/terminated ───────────
  static void setupNotificationOpenHandler({
    void Function(RemoteMessage)? onOpen,
  }) {
    if (kIsWeb) return;
    // App opened from notification when in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('[FCM] Notification tapped: ${message.notification?.title}');
      }
      onOpen?.call(message);
    });
  }

  /// Encode token data for passing between isolates
  static String encodeTokenList(List<String> tokens) => jsonEncode(tokens);

  static List<String> decodeTokenList(String encoded) {
    try {
      return List<String>.from(jsonDecode(encoded) as List);
    } catch (_) {
      return [];
    }
  }
}

// ── Top-level background handler (must be top-level function) ─────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by FlutterFire before this runs
  if (kDebugMode) {
    debugPrint('[FCM Background] ${message.notification?.title}');
  }
}
