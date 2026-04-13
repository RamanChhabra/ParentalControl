// Background tracking: Android = foreground service (location + app usage every 10 min).
// Also enforces blocked apps: when a blocked app is in foreground, brings our app to front.
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import '../../shared/firebase_options_android.dart';

const _prefLastUsageSync = 'background_last_usage_sync_ms';
const _prefBlockedPackages = 'blocked_packages_json';
const _prefShowBlockedNotification = 'show_blocked_app_notification';
const _openAppCooldownSec = 30;

const _normalNotificationTitle = 'Parental Control';
const _normalNotificationContent = 'Location & app usage shared with parent';
const _blockedNotificationTitle = 'App blocked by parent';
const _blockedNotificationContent = 'This app is blocked by your parent. Do not use this app.';

/// Channel used by BackgroundService (Java) for openApp. Must match plugin.
const _bgChannel = MethodChannel(
  'id.flutter/background_service_android_bg',
  JSONMethodCodec(),
);

@pragma('vm:entry-point')
Future<void> onLocationServiceStart(ServiceInstance service) async {
  if (service is! AndroidServiceInstance) return;
  service.on('stop').listen((_) => service.stopSelf());

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: androidFirebaseOptions);

  final prefs = await SharedPreferences.getInstance();
  final deviceId = prefs.getString('child_device_id');
  if (deviceId == null || deviceId.isEmpty) {
    service.stopSelf();
    return;
  }

  await service.setAsForegroundService();
  await service.setForegroundNotificationInfo(
    title: _normalNotificationTitle,
    content: _normalNotificationContent,
  );

  final firestore = FirebaseFirestore.instance;
  const interval = Duration(minutes: 10);

  // Our app package – never treat as blocked (avoid re-opening ourselves).
  const ourPackage = 'com.parentalcontrol.app';

  int lastOpenAppTimeMs = 0;

  // App blocking: check every 3s and bring our app to front if child uses a blocked app.
  Future<void> checkBlockedApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastOpenAppTimeMs < _openAppCooldownSec * 1000) return;
      String? json = prefs.getString(_prefBlockedPackages);
      // If cache empty, fetch rules from Firestore so blocking works even before child reopens app.
      if ((json == null || json == '[]') && deviceId.isNotEmpty) {
        final doc = await firestore.collection('rules').where('device_id', isEqualTo: deviceId).limit(1).get();
        if (doc.docs.isNotEmpty) {
          final data = doc.docs.first.data();
          final list = data['blocked_packages'];
          final packages = list is List ? list.map((e) => e.toString()).toList() : <String>[];
          json = jsonEncode(packages);
          await prefs.setString(_prefBlockedPackages, json);
        }
      }
      if (json == null || json == '[]') return;
      final blocked = (jsonDecode(json) as List<dynamic>).map((e) => e.toString().toLowerCase()).toSet();
      if (blocked.isEmpty) return;
      final hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission != true) return;
      final end = DateTime.now();
      final start = end.subtract(const Duration(seconds: 15));
      final list = await UsageStats.queryUsageStats(start, end);
      if (list.isEmpty) return;
      String? currentPackage;
      int lastUsed = 0;
      for (final info in list) {
        if (info.packageName == null) continue;
        final pkg = info.packageName!;
        if (pkg == ourPackage) continue;
        final ms = _parseLastUsedMs(info.lastTimeUsed);
        if (ms != null && ms > lastUsed) {
          lastUsed = ms;
          currentPackage = pkg;
        }
      }
      if (currentPackage != null && blocked.contains(currentPackage.toLowerCase())) {
        await prefs.setBool(_prefShowBlockedNotification, true);
        await service.setForegroundNotificationInfo(
          title: _blockedNotificationTitle,
          content: _blockedNotificationContent,
        );
        await _bgChannel.invokeMethod('openApp');
        lastOpenAppTimeMs = DateTime.now().millisecondsSinceEpoch;
        Future.delayed(const Duration(seconds: 15), () async {
          await service.setForegroundNotificationInfo(
            title: _normalNotificationTitle,
            content: _normalNotificationContent,
          );
        });
      }
    } catch (_) {}
  }

  int secondsUntilNextLocation = 0;
  const blockerInterval = Duration(seconds: 3);

  while (true) {
    await checkBlockedApp();
    await Future.delayed(blockerInterval);
    secondsUntilNextLocation += blockerInterval.inSeconds;
    if (secondsUntilNextLocation < interval.inSeconds) continue;
    secondsUntilNextLocation = 0;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever &&
          await Geolocator.isLocationServiceEnabled()) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        await firestore.collection('location_logs').add({
          'device_id': deviceId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    try {
      final hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission == true) {
        final end = DateTime.now();
        final lastMs = prefs.getInt(_prefLastUsageSync);
        final start = lastMs != null
            ? DateTime.fromMillisecondsSinceEpoch(lastMs)
            : end.subtract(interval);
        final Map<String, UsageInfo> aggregated =
            await UsageStats.queryAndAggregateUsageStats(start, end);
        final batch = firestore.batch();
        int count = 0;
        for (final entry in aggregated.entries) {
          final info = entry.value;
          if (info.packageName == null || info.packageName!.isEmpty) continue;
          final totalMs = _parseTotalTimeMs(info.totalTimeInForeground);
          final usageMinutes = (totalMs / 60000).round();
          if (usageMinutes <= 0) continue;
          batch.set(firestore.collection('app_usage').doc(), {
            'device_id': deviceId,
            'package_name': info.packageName,
            'app_name': null,
            'usage_minutes': usageMinutes,
            'timestamp': FieldValue.serverTimestamp(),
          });
          if (++count >= 50) break;
        }
        if (count > 0) await batch.commit();
        await prefs.setInt(_prefLastUsageSync, end.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }
}

int _parseTotalTimeMs(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _parseLastUsedMs(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
