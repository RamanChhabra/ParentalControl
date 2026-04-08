/// Child's request to install an app; parent approves or denies.
class AppInstallRequestModel {
  const AppInstallRequestModel({
    required this.id,
    required this.deviceId,
    required this.requestedByUid,
    required this.appName,
    this.packageName,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.parentNote,
  });

  final String id;
  final String deviceId;
  final String requestedByUid;
  final String appName;
  final String? packageName;
  /// pending | approved | denied
  final String status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? parentNote;

  factory AppInstallRequestModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? requestedAt;
    final r = map['requested_at'];
    if (r != null) {
      if (r is DateTime) requestedAt = r;
      else if (r is String) requestedAt = DateTime.tryParse(r);
    }
    requestedAt ??= DateTime.now();

    DateTime? decidedAt;
    final d = map['decided_at'];
    if (d != null) {
      if (d is DateTime) decidedAt = d;
      else if (d is String) decidedAt = DateTime.tryParse(d);
    }

    return AppInstallRequestModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      requestedByUid: map['requested_by_uid'] as String? ?? '',
      appName: map['app_name'] as String? ?? '',
      packageName: map['package_name'] as String?,
      status: map['status'] as String? ?? 'pending',
      requestedAt: requestedAt,
      decidedAt: decidedAt,
      parentNote: map['parent_note'] as String?,
    );
  }
}
