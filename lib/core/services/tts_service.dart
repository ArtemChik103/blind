import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tts_spam_gate.dart';

part 'tts_service.g.dart';

@Riverpod(keepAlive: true)
FlutterTts flutterTts(Ref ref) {
  final tts = FlutterTts();
  unawaited(tts.setLanguage('ru-RU'));
  unawaited(tts.setSpeechRate(0.5));
  unawaited(tts.awaitSpeakCompletion(false));
  ref.onDispose(() {
    unawaited(tts.stop());
  });
  return tts;
}

@Riverpod(keepAlive: true)
TtsService ttsService(Ref ref) {
  final tts = ref.watch(flutterTtsProvider);
  return TtsService(tts);
}

class TtsService {
  final FlutterTts _tts;
  final TtsSpamGate _spamGate = TtsSpamGate();

  TtsService(this._tts);

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> speakUrgent(String text) async {
    if (text.trim().isEmpty) return;
    await stop();
    await _tts.speak(text);
  }

  Future<void> speakIfNotSpam({
    required String key,
    required String text,
  }) async {
    if (key.trim().isEmpty || text.trim().isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (!_spamGate.shouldSpeak(key: key, now: now)) {
      return;
    }
    await speakUrgent(text);
  }
}
