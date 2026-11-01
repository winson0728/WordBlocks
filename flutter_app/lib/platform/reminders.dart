import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One repeating notification a day that reminds the user to review.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 1;
  static bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _ready = true;
  }

  /// Asks for notification permission (Android 13+) and schedules the daily reminder.
  /// Returns false when the user declines the permission.
  static Future<bool> enable(int minuteOfDay) async {
    if (!supported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;
    if (!granted) return false;

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: '字根工坊 · 每日複習',
      body: '花 5 分鐘複習今天的字根，保持連續學習紀錄。',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_review',
          '每日複習提醒',
          channelDescription: '每天提醒你複習字根',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Inexact is fine for a study reminder and needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  static Future<void> disable() async {
    if (!supported) return;
    await _init();
    await _plugin.cancel(id: _id);
  }
}
