/// Call log entry (Android only). Synced from child device to Firestore.
class CallLogModel {
  const CallLogModel({
    required this.id,
    required this.deviceId,
    required this.number,
    this.name,
    required this.type,
    required this.durationSeconds,
    required this.timestamp,
  });

  final String id;
  final String deviceId;
  final String number;
  final String? name;
  /// incoming, outgoing, missed
  final String type;
  final int durationSeconds;
  final DateTime timestamp;

  factory CallLogModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime ts = DateTime.now();
    final t = map['timestamp'];
    if (t != null) {
      if (t is DateTime) ts = t;
      else if (t is String) ts = DateTime.tryParse(t) ?? ts;
    }
    return CallLogModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      number: map['number'] as String? ?? '',
      name: map['name'] as String?,
      type: map['type'] as String? ?? 'unknown',
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      timestamp: ts,
    );
  }
}
