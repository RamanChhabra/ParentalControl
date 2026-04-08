import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('com.parentalcontrol.app/device_owner');
const _prefLastAppliedBlocked = 'device_owner_last_blocked_packages';

/// Returns true if this app is set as Android device owner (via adb).
Future<bool> isDeviceOwner() async {
  if (!Platform.isAndroid) return false;
  try {
    final result = await _channel.invokeMethod<bool>('isDeviceOwner');
    return result == true;
  } catch (_) {
    return false;
  }
}

/// Hide or unhide an app in the launcher. Only works when app is device owner.
Future<bool> setAppBlocked(String packageName, bool blocked) async {
  if (!Platform.isAndroid) return false;
  try {
    await _channel.invokeMethod('setAppBlocked', {
      'packageName': packageName,
      'blocked': blocked,
    });
    return true;
  } catch (_) {
    return false;
  }
}

/// Sync blocked list with device: hide all in [blockedPackages], unhide any that were previously
/// blocked but are no longer in the list. No-op if not device owner.
Future<void> syncBlockedAppsWithDeviceOwner(List<String> blockedPackages) async {
  if (!Platform.isAndroid) return;
  try {
    final isOwner = await isDeviceOwner();
    if (!isOwner) return;
    final prefs = await SharedPreferences.getInstance();
    final previousJson = prefs.getString(_prefLastAppliedBlocked);
    List<String> previous = [];
    if (previousJson != null) {
      try {
        final list = jsonDecode(previousJson);
        if (list is List) previous = list.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    for (final pkg in blockedPackages) {
      if (pkg.isEmpty) continue;
      await setAppBlocked(pkg, true);
    }
    for (final pkg in previous) {
      if (pkg.isEmpty) continue;
      if (!blockedPackages.contains(pkg)) await setAppBlocked(pkg, false);
    }
    await prefs.setString(_prefLastAppliedBlocked, jsonEncode(blockedPackages));
  } catch (_) {}
}
