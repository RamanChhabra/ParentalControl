import 'dart:convert';

import 'package:flutter/services.dart';

class IosScreenTimeTools {
  static const MethodChannel _channel = MethodChannel('ios_screen_time_tools');

  /// Shows the system Screen Time authorization sheet (Family Controls).
  /// Returns true only if access is approved after the flow (deny often does not throw).
  Future<bool> requestScreenTimePermission() async {
    try {
      final dynamic r = await _channel.invokeMethod('requestScreenTimePermission');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Whether Family Controls authorization is currently approved.
  Future<bool> hasScreenTimePermission() async {
    try {
      final dynamic r = await _channel.invokeMethod('hasScreenTimePermission');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Shows the screen for selecting apps to discourage
  Future<String> selectAppsToDiscourage() async {
    try {
      await _channel.invokeMethod('selectAppsToDiscourage');
      return 'App selection screen displayed.';
    } catch (e) {
      return 'Error occurred: $e';
    }
  }

  /// Removes all app restrictions
  Future<String> removeAllRestrictions() async {
    try {
      await _channel.invokeMethod('encourageAll');
      return 'All restrictions removed.';
    } catch (e) {
      return 'Error occurred: $e';
    }
  }

  /// Returns JSON for [AppUsageTrackerIos]: list of `{bundleId, appName, usageMinutes}` (native map is seconds per opaque app key).
  Future<String> getScreenTimeData() async {
    try {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final Map<String, dynamic>? usageData =
          await _channel.invokeMapMethod<String, dynamic>(
        'getScreenTimeData',
        {
          'startDate': oneWeekAgo.millisecondsSinceEpoch,
          'endDate': now.millisecondsSinceEpoch,
        },
      );

      if (usageData == null || usageData.isEmpty) {
        return 'No usage data found.';
      }

      final list = <Map<String, dynamic>>[];
      usageData.forEach((key, rawSeconds) {
        final seconds = switch (rawSeconds) {
          int v => v,
          double v => v.round(),
          _ => int.tryParse('$rawSeconds') ?? 0,
        };
        final minutes = (seconds / 60).round();
        if (minutes <= 0) return;
        list.add({
          'bundleId': key,
          'appName': null,
          'usageMinutes': minutes,
        });
      });

      if (list.isEmpty) return 'No usage data found.';
      return jsonEncode(list);
    } catch (e) {
      return 'Error occurred: $e';
    }
  }
}
