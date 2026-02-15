import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/core/services/tts_spam_gate.dart';

void main() {
  test('suppresses repeats within cooldown', () {
    final gate = TtsSpamGate();
    final t0 = DateTime(2026, 2, 6, 0, 0, 0);

    expect(gate.shouldSpeak(key: 'a', now: t0), isTrue);
    expect(
      gate.shouldSpeak(key: 'a', now: t0.add(const Duration(seconds: 3))),
      isFalse,
    );
    expect(
      gate.shouldSpeak(key: 'a', now: t0.add(const Duration(seconds: 5))),
      isTrue,
    );
  });

  test('allows different keys immediately', () {
    final gate = TtsSpamGate();
    final t0 = DateTime(2026, 2, 6, 0, 0, 0);

    expect(gate.shouldSpeak(key: 'a', now: t0), isTrue);
    expect(
      gate.shouldSpeak(key: 'b', now: t0.add(const Duration(seconds: 1))),
      isTrue,
    );
  });
}
