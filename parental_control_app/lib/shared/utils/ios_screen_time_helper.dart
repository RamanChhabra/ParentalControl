import 'package:flutter/foundation.dart';
import 'package:ios_screen_time_tools/ios_screen_time_tools.dart';
import 'platform_check.dart';

/// iOS only: Screen Time API for app blocking. Requires Family Controls capability.
/// - selectAppsToBlock: opens native picker for user to choose apps to discourage/block.
/// - removeAllAppRestrictions: clears all Screen Time restrictions set by this app.
/// On non-iOS or if plugin fails, methods no-op.
class IosScreenTimeHelper {
  static final IosScreenTimeTools _plugin = IosScreenTimeTools();

  /// Requests Screen Time / Family Controls access (system sheet). Returns true if approved.
  static Future<bool> requestScreenTimeAccess() async {
    if (!isIOS) return false;
    return _plugin.requestScreenTimePermission();
  }

  /// Whether Screen Time access is already approved for this app.
  static Future<bool> hasScreenTimeAccess() async {
    if (!isIOS) return false;
    return _plugin.hasScreenTimePermission();
  }

  /// Opens the system Screen Time app picker. User selects apps to block/discourage.
  /// Returns a result string from the plugin (e.g. success message).
  static Future<String> selectAppsToBlock() async {
    if (!isIOS) return 'Not available on this device';
    try {
      final result = await _plugin.selectAppsToDiscourage();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('IosScreenTimeHelper.selectAppsToBlock: $e');
      return 'Failed: $e';
    }
  }

  /// Removes all app restrictions previously set via Screen Time.
  static Future<String> removeAllAppRestrictions() async {
    if (!isIOS) return 'Not available on this device';
    try {
      final result = await _plugin.removeAllRestrictions();
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('IosScreenTimeHelper.removeAllAppRestrictions: $e');
      return 'Failed: $e';
    }
  }
}
