import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_device_apps/flutter_device_apps.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/utils/platform_check.dart';

/// Android app usage: reads UsageStatsManager via usage_stats and sends to Firestore.
/// Resolves app display name via flutter_device_apps. Runs every 15 min.
class AppUsageTracker {
  static Timer? _timer;
  static bool get isRunning => _timer != null;

  static void startIfNeeded(BuildContext context, {required String deviceId}) {
    if (_timer != null) return;
    final firestore = context.read<FirestoreService>();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _send(firestore, deviceId));
    _send(firestore, deviceId);
  }

  static Future<String?> _appNameForPackage(String packageName) async {
    if (!isAndroid) return null;
    try {
      final info = await FlutterDeviceApps.getApp(packageName, includeIcon: false);
      return info?.appName;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _send(FirestoreService firestore, String deviceId) async {
    try {
      final hasPermission = await UsageStats.checkUsagePermission();
      if (hasPermission != true) {
        await UsageStats.grantUsagePermission();
        return;
      }
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 24));
      final Map<String, UsageInfo> aggregated =
          await UsageStats.queryAndAggregateUsageStats(start, end);
      for (final entry in aggregated.entries) {
        final pkg = entry.key;
        final info = entry.value;
        if (pkg.isEmpty || info.packageName == null) continue;
        final totalMs = _parseTotalTimeMs(info.totalTimeInForeground);
        final usageMinutes = (totalMs / 60000).round();
        if (usageMinutes <= 0) continue;
        final appName = await _appNameForPackage(info.packageName!);
        await firestore.addAppUsage(
          deviceId: deviceId,
          packageName: info.packageName!,
          appName: appName,
          usageMinutes: usageMinutes,
        );
      }
    } catch (_) {}
  }

  /// totalTimeInForeground from Android is in milliseconds (as String or int in the map).
  static int _parseTotalTimeMs(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
