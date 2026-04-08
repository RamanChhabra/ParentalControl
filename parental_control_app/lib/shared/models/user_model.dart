/// User role: parent or child device.
enum UserRole {
  parent,
  child,
}

extension UserRoleX on UserRole {
  String get value => name;
  static UserRole? fromString(String? v) {
    if (v == null) return null;
    for (final e in UserRole.values) {
      if (e.name == v) return e;
    }
    return null;
  }
}
