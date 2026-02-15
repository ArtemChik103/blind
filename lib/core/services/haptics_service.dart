import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vibration/vibration.dart';

import 'haptics_gate.dart';

part 'haptics_service.g.dart';

@Riverpod(keepAlive: true)
HapticsService hapticsService(Ref ref) {
  return HapticsService();
}

class HapticsService {
  final HapticsGate _gate = HapticsGate();

  Future<void> vibrateUrgent() async {
    final now = DateTime.now();
    if (!_gate.shouldVibrateUrgent(now)) {
      return;
    }
    await _vibratePattern(<int>[0, 140, 70, 220]);
  }

  Future<void> vibrateInfo() async {
    final now = DateTime.now();
    if (!_gate.shouldVibrateInfo(now)) {
      return;
    }
    await _vibratePattern(<int>[0, 70]);
  }

  Future<void> vibratePanic() async {
    await _vibratePattern(<int>[0, 260, 100, 260]);
  }

  Future<void> cancel() async {
    await Vibration.cancel();
  }

  Future<void> _vibratePattern(List<int> pattern) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) {
      return;
    }
    await Vibration.vibrate(pattern: pattern);
  }
}
