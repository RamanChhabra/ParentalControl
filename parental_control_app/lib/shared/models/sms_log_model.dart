/// SMS log entry (Android). Synced from child device with consent. Sensitive data.
class SmsLogModel {
  const SmsLogModel({
    required this.id,
    required this.deviceId,
    required this.address,
    required this.body,
    required this.type,
    required this.timestamp,
  });

  final String id;
  final String deviceId;
  final String address;
  final String body;
  /// inbox | sent
  final String type;
  final DateTime timestamp;

  factory SmsLogModel.fromMap(String id, Map<String, dynamic> map) {
    final t = map['timestamp'];
    DateTime ts = DateTime.now();
    if (t != null) {
      if (t is DateTime) ts = t;
      else if (t is String) ts = DateTime.tryParse(t) ?? ts;
    }
    return SmsLogModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      address: map['address'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'inbox',
      timestamp: ts,
    );
  }
}
