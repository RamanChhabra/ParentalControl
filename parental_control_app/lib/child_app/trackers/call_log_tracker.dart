import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:call_log/call_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/utils/platform_check.dart';

const _prefLastCallSync = 'call_log_last_sync_timestamp';

/// Android only: syncs call log to Firestore for parent to view. Runs when child app is open.
class CallLogTracker {
  static bool _syncing = false;

  static Future<void> syncIfNeeded(BuildContext context, {required String deviceId}) async {
    if (!isAndroid || _syncing) return;
    _syncing = true;
    try {
      final firestore = context.read<FirestoreService>();
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefLastCallSync);
      final from = lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : DateTime.now().subtract(const Duration(days: 7));
      final entries = await CallLog.query(dateTimeFrom: from);
      int maxTs = lastMs ?? 0;
      for (final e in entries) {
        final ts = e.timestamp ?? 0;
        if (ts > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          final number = (e.number?.isNotEmpty == true)
              ? e.number!
              : (e.formattedNumber?.isNotEmpty == true)
                  ? e.formattedNumber!
                  : (e.cachedMatchedNumber?.isNotEmpty == true)
                      ? e.cachedMatchedNumber!
                      : '';
          await firestore.addCallLog(
            deviceId: deviceId,
            number: number,
            name: e.name,
            type: _callTypeString(e.callType),
            durationSeconds: e.duration ?? 0,
            timestamp: dt,
          );
          if (ts > maxTs) maxTs = ts;
        }
      }
      if (maxTs > 0) await prefs.setInt(_prefLastCallSync, maxTs);
    } catch (_) {}
    _syncing = false;
  }

  static String _callTypeString(CallType? t) {
    if (t == null) return 'unknown';
    return t.toString().split('.').last;
  }
}
