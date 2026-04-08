import 'package:cloud_firestore/cloud_firestore.dart';

/// Linked device (child's phone) for a parent.
class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.deviceId,
    required this.parentId,
    this.childName,
    this.deviceName,
    this.deviceModel,
    this.pairedAt,
  });

  final String id;
  final String deviceId;
  final String parentId;
  final String? childName;
  final String? deviceName;
  final String? deviceModel;
  final DateTime? pairedAt;

  factory DeviceModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? pairedAt;
    final pt = map['paired_at'];
    if (pt != null) {
      if (pt is Timestamp) {
        pairedAt = pt.toDate();
      } else {
        pairedAt = DateTime.tryParse(pt.toString());
      }
    }
    return DeviceModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      parentId: map['parent_id'] as String? ?? '',
      childName: map['child_name'] as String?,
      deviceName: map['device_name'] as String?,
      deviceModel: map['device_model'] as String?,
      pairedAt: pairedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'parent_id': parentId,
      'child_name': childName,
      'device_name': deviceName,
      'device_model': deviceModel,
      'paired_at': pairedAt?.toIso8601String(),
    };
  }
}
