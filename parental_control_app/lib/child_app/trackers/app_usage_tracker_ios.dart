import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ios_screen_time_tools/ios_screen_time_tools.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/utils/platform_check.dart';

/// iOS app usage: uploads parsed Screen Time JSON from the plugin when available, and always
/// uploads **time the child keeps this app in the foreground** while on the child home screen
/// (Apple does not expose full-device per-app usage to the main app without a Device Activity Report extension).
class AppUsageTrackerIos {
  static Timer? _timer;
  static bool get isRunning => _timer != null;

  /// Seconds accumulated while the child app is in the foreground; uploaded on each sync tick.
  static int _foregroundSecondsPending = 0;
  static DateTime? _iosResumeAt;

  static void addForegroundSeconds(int seconds) {
    if (seconds <= 0) return;
    _foregroundSecondsPending += seconds;
  }

  static void iosAppBecameActive() {
    _iosResumeAt = DateTime.now();
  }

  static void iosAppBackgrounded() {
    final start = _iosResumeAt;
    _iosResumeAt = null;
    if (start == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    addForegroundSeconds(secs);
  }

  /// Moves elapsed foreground time since last resume into the pending bucket and restarts the segment
  /// so long sessions still produce Firestore rows every sync interval.
  static void iosRollForegroundSegmentForSyncTick() {
    final start = _iosResumeAt;
    if (start == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    if (secs > 0) addForegroundSeconds(secs);
    _iosResumeAt = DateTime.now();
  }

  static void startIfNeeded(BuildContext context, {required String deviceId}) {
    if (!isIOS || _timer != null) return;
    final firestore = context.read<FirestoreService>();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _send(firestore, deviceId));
    _send(firestore, deviceId);
  }

  static Future<void> _send(FirestoreService firestore, String deviceId) async {
    try {
      iosRollForegroundSegmentForSyncTick();
      final plugin = IosScreenTimeTools();
      final result = await plugin.getScreenTimeData();
      final list = _parseScreenTimeResult(result);
      for (final entry in list) {
        if (entry.usageMinutes <= 0) continue;
        await firestore.addAppUsage(
          deviceId: deviceId,
          packageName: entry.bundleId,
          appName: entry.appName,
          usageMinutes: entry.usageMinutes,
        );
      }

      final pending = _foregroundSecondsPending;
      if (pending > 0) {
        _foregroundSecondsPending = 0;
        final minutes = (pending / 60).round();
        if (minutes > 0) {
          await firestore.addAppUsage(
            deviceId: deviceId,
            packageName: 'ios.parentalcontrol.foreground',
            appName: 'Parental Control app open on device (not full device Screen Time)',
            usageMinutes: minutes,
          );
        } else {
          _foregroundSecondsPending += pending;
        }
      }
    } catch (_) {
      // Permission not granted or API not available
    }
  }

  /// Parse getScreenTimeData() string (plugin may return JSON array or custom format).
  static List<_IosAppUsage> _parseScreenTimeResult(String result) {
    final list = <_IosAppUsage>[];
    try {
      final decoded = jsonDecode(result);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            list.add(_IosAppUsage(
              bundleId: item['bundleId'] as String? ?? item['bundle_id'] as String? ?? '',
              appName: item['appName'] as String? ?? item['app_name'] as String? ?? item['name'] as String?,
              usageMinutes: _parseMinutes(item['usageMinutes'] ?? item['usage_minutes'] ?? item['usage'] ?? item['totalTime'] ?? 0),
            ));
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        final apps = decoded['apps'] as List? ?? decoded['data'] as List?;
        if (apps != null) {
          for (final item in apps) {
            if (item is Map<String, dynamic>) {
              list.add(_IosAppUsage(
                bundleId: item['bundleId'] as String? ?? item['bundle_id'] as String? ?? '',
                appName: item['appName'] as String? ?? item['app_name'] as String? ?? item['name'] as String?,
                usageMinutes: _parseMinutes(item['usageMinutes'] ?? item['usage_minutes'] ?? item['usage'] ?? item['totalTime'] ?? 0),
              ));
            }
          }
        }
      }
    } catch (_) {
      // If result is plain text (e.g. "No data"), ignore
    }
    return list;
  }

  static int _parseMinutes(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    iosAppBackgrounded();
  }
}

class _IosAppUsage {
  _IosAppUsage({required this.bundleId, this.appName, required this.usageMinutes});
  final String bundleId;
  final String? appName;
  final int usageMinutes;
}
