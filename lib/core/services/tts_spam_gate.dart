class TtsSpamGate {
  String? _lastKey;
  DateTime? _lastTime;

  bool shouldSpeak({
    required String key,
    required DateTime now,
    Duration cooldown = const Duration(seconds: 4),
  }) {
    final lastKey = _lastKey;
    final lastTime = _lastTime;
    if (lastKey == key && lastTime != null) {
      final diff = now.difference(lastTime);
      if (diff < cooldown) {
        return false;
      }
    }

    _lastKey = key;
    _lastTime = now;
    return true;
  }
}
