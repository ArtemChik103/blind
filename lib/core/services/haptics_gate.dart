class HapticsGate {
  DateTime? _lastUrgentAt;
  DateTime? _lastInfoAt;

  bool shouldVibrateUrgent(
    DateTime now, {
    Duration cooldown = const Duration(milliseconds: 1500),
  }) {
    final last = _lastUrgentAt;
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _lastUrgentAt = now;
    return true;
  }

  bool shouldVibrateInfo(
    DateTime now, {
    Duration cooldown = const Duration(milliseconds: 3000),
  }) {
    final last = _lastInfoAt;
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    _lastInfoAt = now;
    return true;
  }
}
