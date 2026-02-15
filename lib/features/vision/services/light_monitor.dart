import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Монитор освещённости с auto-torch функцией
class LightMonitor {
  /// Пороги яркости
  static const int _darkThreshold = 30; // Темно - включить вспышку
  static const int _brightThreshold = 100; // Светло - выключить вспышку

  /// Debounce: не переключать вспышку чаще чем раз в 2 секунды
  static const Duration _hysteresisDuration = Duration(seconds: 2);

  DateTime? _lastFlashChange;
  FlashMode _currentFlashMode = FlashMode.off;

  /// Анализировать кадр и управлять вспышкой
  ///
  /// [image] - CameraImage в формате YUV420
  /// [controller] - CameraController для управления вспышкой
  Future<void> analyzeAndControlFlash(
    CameraImage image,
    CameraController controller,
  ) async {
    // Вычислить среднюю яркость с pixel striding
    final brightness = _calculateBrightness(image);

    // Проверить hysteresis (debounce)
    final now = DateTime.now();
    if (_lastFlashChange != null &&
        now.difference(_lastFlashChange!) < _hysteresisDuration) {
      return; // Слишком рано для переключения
    }

    // Логика включения/выключения вспышки
    FlashMode? newMode;

    if (brightness < _darkThreshold && _currentFlashMode != FlashMode.torch) {
      newMode = FlashMode.torch;
    } else if (brightness > _brightThreshold &&
        _currentFlashMode != FlashMode.off) {
      newMode = FlashMode.off;
    }

    if (newMode != null) {
      try {
        await controller.setFlashMode(newMode);
        _currentFlashMode = newMode;
        _lastFlashChange = now;
      } catch (e) {
        // Игнорируем ошибки flash (не все устройства поддерживают)
      }
    }
  }

  /// Вычислить среднюю яркость изображения используя PIXEL STRIDING
  ///
  /// ВАЖНО: НЕ проходим по всем пикселям! Буфер огромный.
  /// Используем шаг 50 для производительности.
  int _calculateBrightness(CameraImage image) {
    // Получить Y-plane (luminance) - это первый plane в YUV420
    if (image.planes.isEmpty) {
      return 128; // Средняя яркость по умолчанию
    }

    final Uint8List yPlane = image.planes[0].bytes;

    int sum = 0;
    int count = 0;

    // PIXEL STRIDING: читаем каждый 50-й байт для производительности
    for (int i = 0; i < yPlane.length; i += 50) {
      sum += yPlane[i];
      count++;
    }

    if (count == 0) {
      return 128;
    }

    return (sum / count).round();
  }

  /// Сбросить состояние монитора
  void reset() {
    _lastFlashChange = null;
    _currentFlashMode = FlashMode.off;
  }

  /// Получить текущий режим вспышки
  FlashMode get currentFlashMode => _currentFlashMode;
}
