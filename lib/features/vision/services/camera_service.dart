import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:wakelock_plus/wakelock_plus.dart';

/// Провайдер для списка доступных камер
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((
  ref,
) async {
  return await availableCameras();
});

/// Провайдер для CameraService
final cameraServiceProvider =
    legacy.StateNotifierProvider<CameraService, CameraServiceState>((ref) {
      return CameraService();
    });

/// Состояние сервиса камеры
enum CameraStatus { uninitialized, initializing, ready, error }

class CameraServiceState {
  final CameraStatus status;
  final CameraController? controller;
  final String? errorMessage;
  final bool isStreaming;
  final int sensorOrientation;
  final CameraLensDirection lensDirection;

  const CameraServiceState({
    this.status = CameraStatus.uninitialized,
    this.controller,
    this.errorMessage,
    this.isStreaming = false,
    this.sensorOrientation = 0,
    this.lensDirection = CameraLensDirection.back,
  });

  CameraServiceState copyWith({
    CameraStatus? status,
    CameraController? controller,
    String? errorMessage,
    bool? isStreaming,
    int? sensorOrientation,
    CameraLensDirection? lensDirection,
  }) {
    return CameraServiceState(
      status: status ?? this.status,
      controller: controller ?? this.controller,
      errorMessage: errorMessage ?? this.errorMessage,
      isStreaming: isStreaming ?? this.isStreaming,
      sensorOrientation: sensorOrientation ?? this.sensorOrientation,
      lensDirection: lensDirection ?? this.lensDirection,
    );
  }
}

class CameraService extends legacy.StateNotifier<CameraServiceState> {
  CameraService() : super(const CameraServiceState());

  /// Для throttling - последнее время обработки кадра
  DateTime? _lastRun;

  /// Callback для обработки кадров (будет установлен извне)
  void Function(CameraImage image)? onImageAvailable;

  /// Инициализация камеры
  /// ВАЖНО: Использовать ResolutionPreset.medium (640x480)
  /// ВАЖНО: enableAudio: false
  Future<void> initialize(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: 'Камеры не найдены',
      );
      return;
    }

    state = state.copyWith(status: CameraStatus.initializing);

    // Найти заднюю камеру
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.medium, // КРИТИЧНО: Только medium! НЕ high/max
      enableAudio: false, // КРИТИЧНО: Аудио выключено
      imageFormatGroup: ImageFormatGroup.yuv420, // Для Y-plane анализа
    );

    try {
      await controller.initialize();

      // Включить WakeLock чтобы экран не засыпал
      await WakelockPlus.enable();

      state = state.copyWith(
        status: CameraStatus.ready,
        controller: controller,
        sensorOrientation: backCamera.sensorOrientation,
        lensDirection: backCamera.lensDirection,
      );
    } catch (e) {
      state = state.copyWith(
        status: CameraStatus.error,
        errorMessage: 'Ошибка инициализации: $e',
      );
    }
  }

  /// Запустить стрим изображений с throttling
  /// Камера даёт 30 FPS, но нам нужно только 2-3 FPS
  Future<void> startImageStream() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state.isStreaming) return; // Уже запущен

    await controller.startImageStream(_onImageStream);
    state = state.copyWith(isStreaming: true);
  }

  /// Внутренний обработчик стрима с throttling
  void _onImageStream(CameraImage image) {
    final now = DateTime.now();

    // Throttling: пропускаем кадры если прошло меньше 500ms
    if (_lastRun != null &&
        now.difference(_lastRun!) < const Duration(milliseconds: 500)) {
      return;
    }

    _lastRun = now;

    // Передать кадр для обработки (если callback установлен)
    if (onImageAvailable != null) {
      onImageAvailable!(image);
    }
  }

  /// Остановить стрим изображений
  Future<void> stopImageStream() async {
    final controller = state.controller;
    if (controller != null && state.isStreaming) {
      await controller.stopImageStream();
      state = state.copyWith(isStreaming: false);
    }
  }

  Future<void> forceFlashOff() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // Some devices may not support torch changes while streaming/stopped.
    }
  }

  /// Освободить ресурсы
  @override
  void dispose() {
    state.controller?.stopImageStream();
    state.controller?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}
