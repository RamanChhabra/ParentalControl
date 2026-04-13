import 'dart:io';

import 'package:flutter/services.dart';

/// Native Android helpers for parental-control onboarding (Settings intents + permission checks).
/// Kotlin: `ParentalControlAndroidApi` + MethodChannel `com.parentalcontrol.app/android_parental_control`.
const _channel = MethodChannel('com.parentalcontrol.app/android_parental_control');

Future<bool> androidHasUsageStatsPermission() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<void> androidOpenUsageAccessSettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  } catch (_) {}
}

Future<bool> androidIsIgnoringBatteryOptimizations() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<void> androidRequestIgnoreBatteryOptimizations() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
  } catch (_) {}
}

Future<void> androidOpenAccessibilitySettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  } catch (_) {}
}

/// [serviceFlattened] must match Settings, e.g. `com.parentalcontrol.app/com.parentalcontrol.app.MyAccessibilityService`.
Future<bool> androidIsAccessibilityServiceEnabled(String serviceFlattened) async {
  if (!Platform.isAndroid || serviceFlattened.isEmpty) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled', {
      'serviceFlattened': serviceFlattened,
    });
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<bool> androidIsNotificationListenerEnabledForPackage() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isNotificationListenerEnabledForPackage');
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<void> androidOpenNotificationListenerSettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('openNotificationListenerSettings');
  } catch (_) {}
}

Future<bool> androidIsDeviceAdminActive() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isDeviceAdminActive');
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<void> androidRequestDeviceAdmin({String? explanation}) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('requestDeviceAdmin', {
      if (explanation != null) 'explanation': explanation,
    });
  } catch (_) {}
}

Future<bool> androidCanDrawOverlays() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('canDrawOverlays');
    return v == true;
  } catch (_) {
    return false;
  }
}

Future<void> androidOpenManageOverlaySettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('openManageOverlaySettings');
  } catch (_) {}
}

Future<bool> androidIsVpnPrepareNeeded() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isVpnPrepareNeeded');
    return v == true;
  } catch (_) {
    return false;
  }
}

/// Returns true if the system VPN consent UI was opened; false if already granted or failed.
Future<bool> androidLaunchVpnPrepare() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('launchVpnPrepare');
    return v == true;
  } catch (_) {
    return false;
  }
}

/// Opens Settings → Security (OEM path to install user CA / credentials).
Future<void> androidOpenSecuritySettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('openSecuritySettings');
  } catch (_) {}
}

/// Opens system UI to install a user CA from a local file path (app temp dir).
Future<bool> androidInstallUserCaCertificate(String absolutePath) async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await _channel.invokeMethod<bool>('installUserCaCertificate', {
      'path': absolutePath,
    });
    return v == true;
  } catch (_) {
    return false;
  }
}
