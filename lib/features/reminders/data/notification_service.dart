// Local OS notifications (flutter_local_notifications).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_item.dart';

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  NotificationTapCallback? onTap;

  bool get isReady => _ready;

  Future<void> init({NotificationTapCallback? onTap}) async {
    this.onTap = onTap;
    if (kIsWeb) {
      _ready = false;
      return;
    }

    try {
      try {
        tzdata.initializeTimeZones();
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tzdata.initializeTimeZones();
        tz.setLocalLocation(tz.UTC);
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          this.onTap?.call(response.payload);
        },
      );

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready || kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final mac = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final result = await (ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            mac?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ));
        return result ?? false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> reschedule(List<ReminderItem> items) async {
    if (!_ready) return;
    await cancelAll();
    for (final item in items) {
      final when = item.notifyAt;
      final id = item.notificationId;
      if (when == null || id == null) continue;
      if (!when.isAfter(DateTime.now())) continue;
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: item.title,
          body: item.body,
          scheduledDate: tz.TZDateTime.from(when, tz.local),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'accountant_reminders',
              'Reminders',
              channelDescription:
                  'Budget, logging, debt, and scheduled payment reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          payload: item.deepLink.name,
        );
      } catch (_) {
        // Scheduling can fail on unsupported platforms — ignore.
      }
    }
  }
}
