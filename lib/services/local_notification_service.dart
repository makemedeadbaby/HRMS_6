import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalNotificationService
//
// Single owner of FlutterLocalNotificationsPlugin.
// Used to display heads-up banners in THREE scenarios:
//
//   1. App FOREGROUND  → FCM arrives via onMessage stream
//                        → call showFromRemoteMessage()
//
//   2. App BACKGROUND  → FCM data-only message arrives via background isolate
//                        → call showFromRemoteMessage() from background handler
//
//   3. App KILLED      → FCM notification message handled by OS directly
//                        (no Flutter code runs — OS shows it automatically
//                         using the channel registered in MainActivity.kt)
//
// Channel IDs match exactly what Cloud Functions write in the FCM payload
// and what MainActivity.kt registers on Android 8+.
// ─────────────────────────────────────────────────────────────────────────────

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Channel definitions — MUST match MainActivity.kt ─────────────────────
  static const _breakChannel = AndroidNotificationChannel(
    'hrms_break_channel',
    'Break Reminders',
    description: 'Alerts when your break time is over',
    importance: Importance.max,        // heads-up banner
    playSound: true,
    enableVibration: true,
  );

  static const _reminderChannel = AndroidNotificationChannel(
    'hrms_reminder_channel',
    'Shift Reminders',
    description: 'Shift start and check-out reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const _adminChannel = AndroidNotificationChannel(
    'hrms_admin_channel',
    'Admin Notifications',
    description: 'Company-wide announcements and admin alerts',
    importance: Importance.max,        // heads-up banner
    playSound: true,
    enableVibration: true,
  );

  // ── Initialize (call once from main()) ───────────────────────────────────
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    // Android init settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTappedBackground,
    );

    // Register all three channels with Android OS
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(_breakChannel);
      await androidImpl.createNotificationChannel(_reminderChannel);
      await androidImpl.createNotificationChannel(_adminChannel);

      // Request POST_NOTIFICATIONS permission on Android 13+
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
    if (kDebugMode) debugPrint('[LocalNotif] ✅ Initialized with 3 channels');
  }

  // ── Show notification from an FCM RemoteMessage ──────────────────────────
  // Called in FOREGROUND (onMessage) and BACKGROUND (onBackgroundMessage)
  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final notification = message.notification;
    final data = message.data;

    // Determine title + body — prefer explicit fields, fall back to data
    final title = notification?.title ?? data['title'] ?? 'Abhishek HRMS';
    final body  = notification?.body  ?? data['body']  ?? '';

    if (title.isEmpty && body.isEmpty) return;

    // Pick channel based on 'type' field in the FCM data payload
    final type = data['type'] ?? 'custom';
    final channelId = _channelIdForType(type);
    final importance = (channelId == 'hrms_admin_channel' || channelId == 'hrms_break_channel')
        ? Importance.max
        : Importance.high;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelNameForId(channelId),
      channelDescription: _channelDescForId(channelId),
      importance: importance,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Show as heads-up banner even when app is in foreground
      fullScreenIntent: channelId == 'hrms_break_channel',
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    // Use a deterministic ID based on notification_id or hash of title
    final notifId = (data['notification_id'] ?? title).hashCode.abs() % 100000;

    await _plugin.show(notifId, title, body, details, payload: type);

    if (kDebugMode) {
      debugPrint('[LocalNotif] Shown: "$title" on channel $channelId (id=$notifId)');
    }
  }

  // ── Show a direct local notification (for in-app timers) ─────────────────
  static Future<void> showLocal({
    required String title,
    required String body,
    String type = 'custom',
    int? id,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final channelId = _channelIdForType(type);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelNameForId(channelId),
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
    );

    final notifId = id ?? title.hashCode.abs() % 100000;
    await _plugin.show(
      notifId, title, body,
      NotificationDetails(android: androidDetails),
      payload: type,
    );

    if (kDebugMode) debugPrint('[LocalNotif] Local shown: "$title"');
  }

  // ── Cancel a notification by id ──────────────────────────────────────────
  static Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  // ── Cancel all notifications ─────────────────────────────────────────────
  static Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  // ── Notification tap callbacks ────────────────────────────────────────────
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[LocalNotif] Tapped: payload=${response.payload}');
    }
    // Could navigate to specific screen based on payload type
  }

  @pragma('vm:entry-point')
  static void _onNotificationTappedBackground(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[LocalNotif] Background tapped: payload=${response.payload}');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _channelIdForType(String type) {
    switch (type) {
      case 'break_end':       return 'hrms_break_channel';
      case 'logout_reminder':
      case 'shift_reminder':  return 'hrms_reminder_channel';
      default:                return 'hrms_admin_channel';
    }
  }

  static String _channelNameForId(String id) {
    switch (id) {
      case 'hrms_break_channel':    return 'Break Reminders';
      case 'hrms_reminder_channel': return 'Shift Reminders';
      default:                      return 'Admin Notifications';
    }
  }

  static String _channelDescForId(String id) {
    switch (id) {
      case 'hrms_break_channel':    return 'Alerts when your break time is over';
      case 'hrms_reminder_channel': return 'Shift start and check-out reminders';
      default:                      return 'Company-wide announcements and admin alerts';
    }
  }
}
