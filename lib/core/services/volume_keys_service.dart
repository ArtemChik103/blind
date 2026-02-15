import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'volume_keys_service.g.dart';

enum VolumeKey {
  up,
  down,
}

@Riverpod(keepAlive: true)
VolumeKeysService volumeKeysService(Ref ref) {
  return VolumeKeysService();
}

@riverpod
Stream<VolumeKey> volumeKeyEvents(Ref ref) {
  final service = ref.watch(volumeKeysServiceProvider);
  return service.events;
}

class VolumeKeysService {
  static const EventChannel _eventChannel = EventChannel('sonar/volume_keys');

  Stream<VolumeKey> get events {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Stream<VolumeKey>.empty();
    }
    return _eventChannel
        .receiveBroadcastStream()
        .map<VolumeKey?>((event) {
      final value = event?.toString();
      if (value == 'up') {
        return VolumeKey.up;
      }
      if (value == 'down') {
        return VolumeKey.down;
      }
      return null;
    }).where((event) => event != null).cast<VolumeKey>();
  }
}
