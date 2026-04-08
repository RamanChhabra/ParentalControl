/// Parental rules for a device: blocked apps, screen time limit, per-app limits, etc.
class RulesModel {
  const RulesModel({
    required this.deviceId,
    this.blockedPackages = const [],
    this.screenTimeLimitMinutes,
    this.appTimeLimitMinutes = const {},
    this.bedtimeStart,
    this.bedtimeEnd,
    this.blockedDomains = const [],
    this.allowedDomains = const [],
    this.updatedAt,
  });

  final String deviceId;
  final List<String> blockedPackages;
  /// Global daily screen time limit (minutes).
  final int? screenTimeLimitMinutes;
  /// Per-app daily limit: package name -> max minutes per day.
  final Map<String, int> appTimeLimitMinutes;
  final String? bedtimeStart; // e.g. "21:00"
  final String? bedtimeEnd;   // e.g. "07:00"
  /// Domains to block in Safe Browser (e.g. facebook.com). Blacklist when allowedDomains is empty.
  final List<String> blockedDomains;
  /// When non-empty, only these domains are allowed (whitelist). E.g. school.edu, wikipedia.org.
  final List<String> allowedDomains;
  final DateTime? updatedAt;

  factory RulesModel.fromMap(String deviceId, Map<String, dynamic>? map) {
    if (map == null) return RulesModel(deviceId: deviceId);
    final blocked = map['blocked_packages'];
    final appLimits = map['app_time_limit_minutes'];
    Map<String, int> limits = {};
    if (appLimits is Map) {
      for (final e in appLimits.entries) {
        final v = e.value;
        if (v is num) limits[e.key.toString()] = v.toInt();
      }
    }
    final blockedD = map['blocked_domains'];
    final allowedD = map['allowed_domains'];
    return RulesModel(
      deviceId: deviceId,
      blockedPackages: blocked is List
          ? blocked.map((e) => e.toString()).toList()
          : const [],
      screenTimeLimitMinutes: (map['screen_time_limit_minutes'] as num?)?.toInt(),
      appTimeLimitMinutes: limits,
      bedtimeStart: map['bedtime_start'] as String?,
      bedtimeEnd: map['bedtime_end'] as String?,
      blockedDomains: blockedD is List ? blockedD.map((e) => e.toString()).toList() : const [],
      allowedDomains: allowedD is List ? allowedD.map((e) => e.toString()).toList() : const [],
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'blocked_packages': blockedPackages,
      'screen_time_limit_minutes': screenTimeLimitMinutes,
      'app_time_limit_minutes': appTimeLimitMinutes,
      'bedtime_start': bedtimeStart,
      'bedtime_end': bedtimeEnd,
      'blocked_domains': blockedDomains,
      'allowed_domains': allowedDomains,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  RulesModel copyWith({
    List<String>? blockedPackages,
    int? screenTimeLimitMinutes,
    Map<String, int>? appTimeLimitMinutes,
    String? bedtimeStart,
    String? bedtimeEnd,
    List<String>? blockedDomains,
    List<String>? allowedDomains,
  }) {
    return RulesModel(
      deviceId: deviceId,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      screenTimeLimitMinutes: screenTimeLimitMinutes ?? this.screenTimeLimitMinutes,
      appTimeLimitMinutes: appTimeLimitMinutes ?? this.appTimeLimitMinutes,
      bedtimeStart: bedtimeStart ?? this.bedtimeStart,
      bedtimeEnd: bedtimeEnd ?? this.bedtimeEnd,
      blockedDomains: blockedDomains ?? this.blockedDomains,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      updatedAt: updatedAt,
    );
  }
}
