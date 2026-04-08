/// Location log from child device.
class LocationModel {
  const LocationModel({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  final String id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  factory LocationModel.fromMap(String id, Map<String, dynamic> map) {
    return LocationModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
