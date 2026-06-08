import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalNotificationService
//
// ARCHITECTURE — how notifications reach the user in each app state:
//
//  ┌───────────────┬────────────────────────────────────────────────────────┐
//  │ App FOREGROUND│ FCM onMessage → setupForegroundHandler()               │
//  │               │   → LocalNotificationService.show()                    │
//  │               │   (OS silently drops FCM when app is open by default)  │
//  ├───────────────┼────────────────────────────────────────────────────────┤
//  │ App BACKGROUND│ OS receives FCM → shows notification automatically     │
//  │ (minimised)   │ because Cloud Function sends notification{} block      │
//  │               │ No Flutter code needed for this state                  │
//  ├───────────────┼────────────────────────────────────────────────────────┤
//  │ App KILLED    │ OS receives FCM → shows notification automatically     │
//  │ (swiped away) │ Same reason — notification{} block in FCM payload      │
//  │               │ Background isolate handler runs AFTER OS shows it      │
//  └───────────────┴────────────────────────────────────────────────────────┘
//
// KEY INSIGHT: For background + killed states, the OS handles display
// automatically as long as the FCM message contains a notification{} block
// AND the channel ID matches a registered channel.
//
// The background Dart isolate is a SEPARATE VM — static variables don't
// carry over. That's why we create a fresh plugin instance each time.
// ─────────────────────────────────────────────────────────────────────────────

// ── Channel ID constants — shared between main and background isolate ────────
const kBreakChannelId    = 'hrms_break_channel';
const kReminderChannelId = 'hrms_reminder_channel';
const kAdminChannelId    = 'hrms_admin_channel';

class LocalNotificationService {
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  static FlutterLocalNotificationsPlugin get _instance {
    _plugin ??= FlutterLocalNotificationsPlugin();
    return _plugin!;
  }

  // ── Initialize — safe to call multiple times ─────────────────────────────
  static Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings   = InitializationSettings(android: androidSettings);

    await _instance.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    // Create channels via the Android-specific implementation
    final android = _instance.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        kBreakChannelId,
        'Break Reminders',
        description: 'Alerts when your break time is over',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        kReminderChannelId,
        'Shift Reminders',
        description: 'Shift start and check-out reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        kAdminChannelId,
        'Admin Notifications',
        description: 'Company-wide announcements and admin alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));

      // Ask for POST_NOTIFICATIONS permission (Android 13+)
      final granted = await android.requestNotificationsPermission();
      if (kDebugMode) debugPrint('[LocalNotif] Permission granted: $granted');
    }

    _initialized = true;
    if (kDebugMode) debugPrint('[LocalNotif] ✅ Initialized');
  }

  // ── Show notification from an FCM RemoteMessage ──────────────────────────
  static Future<void> showFromRemoteMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final title  = message.notification?.title
        ?? message.data['title'] as String?
        ?? 'Abhishek HRMS';
    final body   = message.notification?.body
        ?? message.data['body'] as String?
        ?? '';
    final type   = (message.data['type'] as String?) ?? 'custom';

    await show(title: title, body: body, type: type,
        id: (message.data['notification_id'] ?? title).hashCode.abs() % 100000);
  }

  // ── Core show method ─────────────────────────────────────────────────────
  static Future<void> show({
    required String title,
    required String body,
    String type = 'custom',
    int? id,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final channelId = _channelFor(type);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName(channelId),
        channelDescription: _channelDesc(channelId),
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(body),
        // Forces heads-up banner even when app is in foreground
        fullScreenIntent: channelId == kBreakChannelId,
        icon: '@mipmap/ic_launcher',
        // Ticker text shown in status bar
        ticker: title,
      ),
    );

    final notifId = id ?? title.hashCode.abs() % 100000;
    await _instance.show(notifId, title, body, details, payload: type);

    if (kDebugMode) debugPrint('[LocalNotif] ✅ Shown "$title" → $channelId');
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  static Future<void> cancel(int id) async {
    if (_initialized) await _instance.cancel(id);
  }

  static Future<void> cancelAll() async {
    if (_initialized) await _instance.cancelAll();
  }

  // ── Tap handlers ──────────────────────────────────────────────────────────
  static void _onTap(NotificationResponse r) {
    if (kDebugMode) debugPrint('[LocalNotif] Tapped: ${r.payload}');
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse r) {
    if (kDebugMode) debugPrint('[LocalNotif] BG tapped: ${r.payload}');
  }

  // ── Channel helpers ───────────────────────────────────────────────────────
  static String _channelFor(String type) {
    switch (type) {
      case 'break_end':                      return kBreakChannelId;
      case 'logout_reminder':
      case 'shift_reminder':                 return kReminderChannelId;
      default:                               return kAdminChannelId;
    }
  }

  static String _channelName(String id) {
    switch (id) {
      case kBreakChannelId:    return 'Break Reminders';
      case kReminderChannelId: return 'Shift Reminders';
      default:                 return 'Admin Notifications';
    }
  }

  static String _channelDesc(String id) {
    switch (id) {
      case kBreakChannelId:    return 'Alerts when your break time is over';
      case kReminderChannelId: return 'Shift start and check-out reminders';
      default:                 return 'Company-wide announcements and admin alerts';
    }
  }
}
