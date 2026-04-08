import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/utils/platform_check.dart';

const prefSmsConsentGiven = 'sms_sharing_consent_given';
const _prefLastSmsSync = 'sms_last_sync_timestamp';

/// Android only: syncs SMS to Firestore after child has given consent. Sensitive.
class SmsTracker {
  static bool _syncing = false;

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefSmsConsentGiven) == true;
  }

  static Future<void> setConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefSmsConsentGiven, value);
  }

  static Future<void> syncIfNeeded(BuildContext context, {required String deviceId}) async {
    if (!isAndroid || _syncing) return;
    final consented = await hasConsent();
    if (!consented) return;
    _syncing = true;
    try {
      final firestore = context.read<FirestoreService>();
      final telephony = Telephony.instance;
      final hasPermission = await telephony.requestPhoneAndSmsPermissions ?? false;
      if (!hasPermission) {
        _syncing = false;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefLastSmsSync);
      final since = lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : DateTime.now().subtract(const Duration(days: 7));
      int maxTs = lastMs ?? 0;

      final inbox = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      int count = 0;
      for (final msg in inbox) {
        if (count >= 80) break;
        final dateMs = msg.date;
        if (dateMs != null && DateTime.fromMillisecondsSinceEpoch(dateMs).isAfter(since)) {
          await firestore.addSmsLog(
            deviceId: deviceId,
            address: msg.address ?? '',
            body: msg.body ?? '',
            type: 'inbox',
            timestamp: DateTime.fromMillisecondsSinceEpoch(dateMs),
          );
          if (dateMs > maxTs) maxTs = dateMs;
          count++;
        }
      }

      final sent = await telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      count = 0;
      for (final msg in sent) {
        if (count >= 80) break;
        final dateMs = msg.date;
        if (dateMs != null && DateTime.fromMillisecondsSinceEpoch(dateMs).isAfter(since)) {
          await firestore.addSmsLog(
            deviceId: deviceId,
            address: msg.address ?? '',
            body: msg.body ?? '',
            type: 'sent',
            timestamp: DateTime.fromMillisecondsSinceEpoch(dateMs),
          );
          if (dateMs > maxTs) maxTs = dateMs;
          count++;
        }
      }

      if (maxTs > 0) await prefs.setInt(_prefLastSmsSync, maxTs);
    } catch (_) {}
    _syncing = false;
  }
}
