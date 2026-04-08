import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import '../models/app_usage_model.dart';
import '../models/location_model.dart';
import '../models/rules_model.dart';
import '../models/call_log_model.dart';
import '../models/sms_log_model.dart';
import '../models/app_install_request_model.dart';

/// Central Firestore access: devices, app_usage, location_logs, rules, call_logs, sms_logs, app_install_requests.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _devices =>
      _firestore.collection('devices');
  CollectionReference<Map<String, dynamic>> get _appUsage =>
      _firestore.collection('app_usage');
  CollectionReference<Map<String, dynamic>> get _locationLogs =>
      _firestore.collection('location_logs');
  CollectionReference<Map<String, dynamic>> get _rules =>
      _firestore.collection('rules');
  CollectionReference<Map<String, dynamic>> get _callLogs =>
      _firestore.collection('call_logs');
  CollectionReference<Map<String, dynamic>> get _smsLogs =>
      _firestore.collection('sms_logs');
  CollectionReference<Map<String, dynamic>> get _appInstallRequests =>
      _firestore.collection('app_install_requests');
  CollectionReference<Map<String, dynamic>> get _pairingCodes =>
      _firestore.collection('pairing_codes');

  // ---------- Pairing ----------
  /// Parent: create a 6-digit code valid for 10 minutes.
  Future<String> createPairingCode(String parentId) async {
    final code = _randomCode(6);
    await _pairingCodes.doc(code).set({
      'parent_id': parentId,
      'created_at': FieldValue.serverTimestamp(),
    });
    return code;
  }

  static String _randomCode(int length) {
    final r = DateTime.now().millisecondsSinceEpoch % 1000000;
    return r.toString().padLeft(length, '0').substring(0, length);
  }

  /// Child: claim code and return parent_id if valid. Deletes code after use.
  Future<String?> claimPairingCode(String code) async {
    final doc = await _pairingCodes.doc(code).get();
    if (!doc.exists) return null;
    final parentId = doc.data()?['parent_id'] as String?;
    if (parentId == null) return null;
    await _pairingCodes.doc(code).delete();
    return parentId;
  }

  // ---------- Devices ----------
  /// Uses deviceId as document id so re-pairing merges child_uid into existing doc.
  Future<String> addDevice({
    required String deviceId,
    required String parentId,
    String? childUid,
    String? childName,
    String? deviceName,
    String? deviceModel,
  }) async {
    final data = <String, dynamic>{
      'device_id': deviceId,
      'parent_id': parentId,
      'child_name': childName,
      'device_name': deviceName,
      'device_model': deviceModel,
      'paired_at': FieldValue.serverTimestamp(),
    };
    if (childUid != null && childUid.isNotEmpty) {
      data['child_uid'] = childUid;
    }
    await _devices.doc(deviceId).set(data, SetOptions(merge: true));
    return deviceId;
  }

  Future<DeviceModel?> getDeviceByDeviceId(String deviceId) async {
    final doc = await _devices.doc(deviceId).get();
    if (!doc.exists) return null;
    return DeviceModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateDeviceChildName(String deviceId, String childName) async {
    await _devices.doc(deviceId).update({'child_name': childName});
  }

  Stream<List<DeviceModel>> watchDevicesForParent(String parentId) {
    return _devices
        .where('parent_id', isEqualTo: parentId)
        .snapshots()
        .map((s) => s.docs.map((d) => DeviceModel.fromMap(d.id, d.data())).toList());
  }

  // ---------- App usage ----------
  Future<void> addAppUsage({
    required String deviceId,
    required String packageName,
    String? appName,
    required int usageMinutes,
  }) async {
    await _appUsage.add({
      'device_id': deviceId,
      'package_name': packageName,
      'app_name': appName,
      'usage_minutes': usageMinutes,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppUsageModel>> watchAppUsageForDevice(String deviceId, {int limit = 200}) {
    return _appUsage
        .where('device_id', isEqualTo: deviceId)
        .limit(limit)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['timestamp'] = (data['timestamp'] as Timestamp?)?.toDate().toIso8601String();
        return AppUsageModel.fromMap(d.id, data);
      }).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  Future<List<AppUsageModel>> getAppUsageForDevice(String deviceId, {int limitCount = 100}) async {
    final q = await _appUsage
        .where('device_id', isEqualTo: deviceId)
        .limit(limitCount)
        .get();
    final list = q.docs.map((d) {
      final data = d.data();
      data['timestamp'] = (data['timestamp'] as Timestamp?)?.toDate().toIso8601String();
      return AppUsageModel.fromMap(d.id, data);
    }).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ---------- Location ----------
  Future<void> addLocationLog({
    required String deviceId,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    await _locationLogs.add({
      'device_id': deviceId,
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LocationModel>> watchLocationForDevice(String deviceId, {int limit = 50}) {
    return _locationLogs
        .where('device_id', isEqualTo: deviceId)
        .limit(limit)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) {
            final data = d.data();
            data['timestamp'] = (data['timestamp'] as Timestamp?)?.toDate().toIso8601String();
            return LocationModel.fromMap(d.id, data);
          }).toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list.take(limit).toList();
        });
  }

  // ---------- Rules ----------
  Future<void> setRules(String deviceId, RulesModel rules) async {
    final q = await _rules.where('device_id', isEqualTo: deviceId).limit(1).get();
    if (q.docs.isEmpty) {
      await _rules.add(rules.toMap());
    } else {
      await q.docs.first.reference.update({
        ...rules.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<RulesModel> getRules(String deviceId) async {
    final q = await _rules.where('device_id', isEqualTo: deviceId).limit(1).get();
    if (q.docs.isEmpty) return RulesModel(deviceId: deviceId);
    final data = q.docs.first.data();
    data['updated_at'] = (data['updated_at'] as Timestamp?)?.toDate().toIso8601String();
    return RulesModel.fromMap(deviceId, data);
  }

  Stream<RulesModel> watchRules(String deviceId) {
    return _rules
        .where('device_id', isEqualTo: deviceId)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return RulesModel(deviceId: deviceId);
      final data = s.docs.first.data();
      data['updated_at'] = (data['updated_at'] as Timestamp?)?.toDate().toIso8601String();
      return RulesModel.fromMap(deviceId, data);
    });
  }

  // ---------- Call logs (Android child device) ----------
  Future<void> addCallLog({
    required String deviceId,
    required String number,
    String? name,
    required String type,
    required int durationSeconds,
    required DateTime timestamp,
  }) async {
    await _callLogs.add({
      'device_id': deviceId,
      'number': number,
      'name': name,
      'type': type,
      'duration_seconds': durationSeconds,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Stream<List<CallLogModel>> watchCallLogsForDevice(String deviceId, {int limit = 100}) {
    return _callLogs
        .where('device_id', isEqualTo: deviceId)
        .limit(limit)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['timestamp'] = (data['timestamp'] is String)
            ? data['timestamp']
            : (data['timestamp'] as Timestamp?)?.toDate().toIso8601String();
        return CallLogModel.fromMap(d.id, data);
      }).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  // ---------- SMS logs (Android, with child consent) ----------
  Future<void> addSmsLog({
    required String deviceId,
    required String address,
    required String body,
    required String type,
    required DateTime timestamp,
  }) async {
    await _smsLogs.add({
      'device_id': deviceId,
      'address': address,
      'body': body.length > 500 ? body.substring(0, 500) : body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Stream<List<SmsLogModel>> watchSmsForDevice(String deviceId, {int limit = 100}) {
    return _smsLogs
        .where('device_id', isEqualTo: deviceId)
        .limit(limit)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['timestamp'] = (data['timestamp'] is String)
            ? data['timestamp']
            : (data['timestamp'] as Timestamp?)?.toDate().toIso8601String();
        return SmsLogModel.fromMap(d.id, data);
      }).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  // ---------- App install requests ----------
  Future<String> addAppInstallRequest({
    required String deviceId,
    required String requestedByUid,
    required String appName,
    String? packageName,
  }) async {
    final ref = await _appInstallRequests.add({
      'device_id': deviceId,
      'requested_by_uid': requestedByUid,
      'app_name': appName,
      'package_name': packageName,
      'status': 'pending',
      'requested_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> setAppInstallRequestStatus(
    String requestId,
    String status, {
    String? parentNote,
  }) async {
    await _appInstallRequests.doc(requestId).update({
      'status': status,
      'decided_at': FieldValue.serverTimestamp(),
      if (parentNote != null) 'parent_note': parentNote,
    });
  }

  Stream<List<AppInstallRequestModel>> watchAppInstallRequestsForDevice(String deviceId) {
    return _appInstallRequests
        .where('device_id', isEqualTo: deviceId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['requested_at'] = (data['requested_at'] as Timestamp?)?.toDate().toIso8601String();
        data['decided_at'] = (data['decided_at'] as Timestamp?)?.toDate().toIso8601String();
        return AppInstallRequestModel.fromMap(d.id, data);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }
}
