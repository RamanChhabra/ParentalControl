/// Single app usage record (sent from child device).
class AppUsageModel {
  const AppUsageModel({
    required this.id,
    required this.deviceId,
    required this.packageName,
    this.appName,
    required this.usageMinutes,
    required this.timestamp,
  });

  final String id;
  final String deviceId;
  final String packageName;
  final String? appName;
  final int usageMinutes;
  final DateTime timestamp;

  factory AppUsageModel.fromMap(String id, Map<String, dynamic> map) {
    return AppUsageModel(
      id: id,
      deviceId: map['device_id'] as String? ?? '',
      packageName: map['package_name'] as String? ?? '',
      appName: map['app_name'] as String?,
      usageMinutes: (map['usage_minutes'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'package_name': packageName,
      'app_name': appName,
      'usage_minutes': usageMinutes,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
