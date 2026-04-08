import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefShowBlockedNotification = 'show_blocked_app_notification';
const _channelId = 'blocked_app_channel';
const _channelName = 'App blocked';
const _notificationId = 9001;

FlutterLocalNotificationsPlugin? _plugin;

/// Initialize local notifications for "blocked app" alerts (Android). Call from main().
Future<void> initBlockedAppNotification() async {
  if (!Platform.isAndroid) return;
  _plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin!.initialize(InitializationSettings(android: android));
  final androidPlugin = _plugin!.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Shown when your parent has blocked an app you tried to use.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ),
  );
  await androidPlugin?.requestNotificationsPermission();
}

/// If the background service set the flag (child used a blocked app), show a heads-up notification and clear the flag.
Future<void> showBlockedAppNotificationIfNeeded() async {
  if (_plugin == null || !Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefShowBlockedNotification) != true) return;
  await prefs.remove(_prefShowBlockedNotification);
  await _plugin!.show(
    _notificationId,
    'App blocked by parent',
    'This app is blocked by your parent. Do not use this app.',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
    ),
  );
}
