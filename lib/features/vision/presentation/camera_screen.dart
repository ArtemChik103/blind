import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sonar/core/services/accessibility_modes.dart';
import 'package:sonar/core/services/haptics_service.dart';
import 'package:sonar/core/services/tts_service.dart';

import '../domain/label_translation_map_ru.dart';
import '../domain/simple_object.dart';
import '../domain/spatial_calculator.dart';
import '../services/camera_service.dart';
import '../services/detection_provider.dart';
import '../services/detection_service.dart';
import '../services/light_monitor.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  final LightMonitor _lightMonitor = LightMonitor();
  bool _isPermissionGranted = false;
  List<SimpleObject> _latestDetectedObjects = <SimpleObject>[];

  ProviderSubscription<List<SimpleObject>>? _detectedObjectsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectedObjectsSub = ref.listenManual<List<SimpleObject>>(
      detectedObjectsProvider,
      (previous, next) {
        _latestDetectedObjects = next;
        _handleDetectedObjects(next);
      },
    );
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detectedObjectsSub?.close();
    _detectedObjectsSub = null;
    unawaited(ref.read(hapticsServiceProvider).cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeAfterBackground());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseForBackground());
    }
  }

  Future<void> _initCamera() async {
    // 1. Request Permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _isPermissionGranted = false);
      return;
    }
    setState(() => _isPermissionGranted = true);

    // 2. Get available cameras
    final camerasAsync = await ref.read(availableCamerasProvider.future);

    // 3. Initialize service
    final cameraService = ref.read(cameraServiceProvider.notifier);
    await cameraService.initialize(camerasAsync);

    // 4. Set callback for frame processing
    cameraService.onImageAvailable = _onImageAvailable;

    // 5. Start stream
    await cameraService.startImageStream();
  }

  /// Callback called every ~500ms (throttled)
  void _onImageAvailable(CameraImage image) {
    final cameraState = ref.read(cameraServiceProvider);
    final controller = cameraState.controller;
    final detectionService = ref.read(detectionServiceProvider);

    if (controller != null) {
      // 1. Analyze brightness and control flash
      _lightMonitor.analyzeAndControlFlash(image, controller);

      // 2. Run ML detection
      final rotationDegrees = _getRotationDegrees(
        sensorOrientation: controller.description.sensorOrientation,
        deviceOrientation: controller.value.deviceOrientation,
        lensDirection: controller.description.lensDirection,
      );
      detectionService.processFrame(image, rotationDegrees);
    }
  }

  void _handleDetectedObjects(List<SimpleObject> objects) {
    if (!mounted || objects.isEmpty) return;

    final cameraState = ref.read(cameraServiceProvider);
    final controller = cameraState.controller;
    final previewSize = controller?.value.previewSize;
    if (controller == null || previewSize == null) {
      return;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;
    final screenSize = mediaQuery.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return;
    }

    _SpeakCandidate? best;

    for (final obj in objects) {
      final scaled = _scaleToScreen(obj, previewSize, screenSize);
      final description = SpatialCalculator.describe(
        left: scaled.left,
        top: scaled.top,
        right: scaled.right,
        bottom: scaled.bottom,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height,
      );
      if (description == null) {
        continue;
      }

      final labelRu = translateCocoLabelToRu(obj.label);
      final direction = SpatialCalculator.directionToRu(description.direction)
          .toLowerCase();
      final distance = SpatialCalculator.distanceToRu(description.distance)
          .toLowerCase();
      final text = '$labelRu $direction, $distance';
      final key = '$labelRu|$direction|$distance';

      final areaRatio = _areaRatio(
        left: scaled.left,
        top: scaled.top,
        right: scaled.right,
        bottom: scaled.bottom,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height,
      );
      final candidate = _SpeakCandidate(
        key: key,
        text: text,
        distancePriority:
            description.distance == SpatialDistance.close ? 2 : 1,
        distance: description.distance,
        areaRatio: areaRatio,
        confidence: obj.confidence,
      );

      if (best == null || _isBetter(candidate, best)) {
        best = candidate;
      }
    }

    if (best != null) {
      final silenceEnabled = ref.read(silenceModeProvider);
      if (!silenceEnabled) {
        unawaited(
          ref.read(ttsServiceProvider).speakIfNotSpam(
                key: best.key,
                text: best.text,
              ),
        );

        final haptics = ref.read(hapticsServiceProvider);
        if (best.distance == SpatialDistance.close) {
          unawaited(haptics.vibrateUrgent());
        } else {
          unawaited(haptics.vibrateInfo());
        }
      }
    }
  }

  _ScaledBox _scaleToScreen(
    SimpleObject object,
    Size previewSize,
    Size screenSize,
  ) {
    final scaleX = screenSize.width / previewSize.height;
    final scaleY = screenSize.height / previewSize.width;
    return _ScaledBox(
      left: object.left * scaleX,
      top: object.top * scaleY,
      right: object.right * scaleX,
      bottom: object.bottom * scaleY,
    );
  }

  double _areaRatio({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double screenWidth,
    required double screenHeight,
  }) {
    final area = (right - left) * (bottom - top);
    final screenArea = screenWidth * screenHeight;
    if (area <= 0 || screenArea <= 0) {
      return 0;
    }
    return area / screenArea;
  }

  bool _isBetter(_SpeakCandidate a, _SpeakCandidate b) {
    if (a.distancePriority != b.distancePriority) {
      return a.distancePriority > b.distancePriority;
    }
    if (a.areaRatio != b.areaRatio) {
      return a.areaRatio > b.areaRatio;
    }
    return a.confidence > b.confidence;
  }

  int _getRotationDegrees({
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required CameraLensDirection lensDirection,
  }) {
    final int deviceRotation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };

    if (lensDirection == CameraLensDirection.front) {
      return (sensorOrientation + deviceRotation) % 360;
    }
    return (sensorOrientation - deviceRotation + 360) % 360;
  }

  Future<void> _pauseForBackground() async {
    final cameraService = ref.read(cameraServiceProvider.notifier);
    await cameraService.stopImageStream();
    await cameraService.forceFlashOff();
    _lightMonitor.reset();
    await ref.read(ttsServiceProvider).stop();
    await ref.read(hapticsServiceProvider).cancel();
  }

  Future<void> _resumeAfterBackground() async {
    if (!_isPermissionGranted) {
      return;
    }
    await ref.read(cameraServiceProvider.notifier).startImageStream();
  }

  Future<void> _handleDoubleTap() async {
    final silenceNotifier = ref.read(silenceModeProvider.notifier);
    await silenceNotifier.toggle();
    final isSilent = ref.read(silenceModeProvider);
    if (isSilent) {
      await ref.read(ttsServiceProvider).stop();
      await ref.read(hapticsServiceProvider).vibrateInfo();
      return;
    }
    await ref.read(ttsServiceProvider).speakUrgent('Режим тишины выключен.');
  }

  Future<void> _handleLongPress() async {
    await _speakInfoSummary();
  }

  Future<void> _speakInfoSummary() async {
    final summary = _buildInfoSummary();
    await ref.read(ttsServiceProvider).speakUrgent(summary);
  }

  String _buildInfoSummary() {
    if (_latestDetectedObjects.isEmpty) {
      return 'Пока не вижу близких объектов.';
    }

    final cameraState = ref.read(cameraServiceProvider);
    final controller = cameraState.controller;
    final previewSize = controller?.value.previewSize;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (previewSize == null || mediaQuery == null) {
      return 'Информация пока недоступна.';
    }
    final screenSize = mediaQuery.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return 'Информация пока недоступна.';
    }

    final phrases = <String>[];
    final dedupe = <String>{};

    for (final obj in _latestDetectedObjects) {
      final scaled = _scaleToScreen(obj, previewSize, screenSize);
      final description = SpatialCalculator.describe(
        left: scaled.left,
        top: scaled.top,
        right: scaled.right,
        bottom: scaled.bottom,
        screenWidth: screenSize.width,
        screenHeight: screenSize.height,
      );
      if (description == null) {
        continue;
      }

      final labelRu = translateCocoLabelToRu(obj.label);
      final direction = SpatialCalculator.directionToRu(description.direction)
          .toLowerCase();
      final distance = SpatialCalculator.distanceToRu(description.distance)
          .toLowerCase();
      final phrase = '$labelRu $direction, $distance';
      if (dedupe.add(phrase)) {
        phrases.add(phrase);
      }
      if (phrases.length >= 3) {
        break;
      }
    }

    if (phrases.isEmpty) {
      return 'Пока не вижу близких объектов.';
    }
    return 'Вижу: ${phrases.join('; ')}.';
  }

  String _buildSemanticsStatus({
    required CameraServiceState cameraState,
    required bool silenceEnabled,
    required int objectCount,
  }) {
    final silenceText = silenceEnabled
        ? 'режим тишины включен'
        : 'режим тишины выключен';
    final cameraText = !cameraState.isStreaming
        ? 'камера на паузе'
        : 'камера активна';
    return '$cameraText, режим сканирования, $silenceText, обнаружено объектов: $objectCount. Двойное касание переключает тишину. Долгое нажатие озвучивает сводку.';
  }

  String _buildOverlayStatus({
    required bool silenceEnabled,
    required int objectCount,
  }) {
    final silenceText = silenceEnabled ? 'Тишина: ВКЛ' : 'Тишина: ВЫКЛ';
    return 'Сканирование · $silenceText · Объектов: $objectCount';
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraServiceProvider);
    final silenceEnabled = ref.watch(silenceModeProvider);
    final detectedObjects = ref.watch(detectedObjectsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Сонар'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Semantics(
        container: true,
        liveRegion: true,
        label: _buildSemanticsStatus(
          cameraState: cameraState,
          silenceEnabled: silenceEnabled,
          objectCount: detectedObjects.length,
        ),
        child: _buildBody(
          cameraState: cameraState,
          silenceEnabled: silenceEnabled,
          detectedObjects: detectedObjects,
        ),
      ),
    );
  }

  Widget _buildBody({
    required CameraServiceState cameraState,
    required bool silenceEnabled,
    required List<SimpleObject> detectedObjects,
  }) {
    if (!_isPermissionGranted && cameraState.status != CameraStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Требуется разрешение на камеру',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Предоставить доступ к камере',
              child: ElevatedButton(
                onPressed: _initCamera,
                child: const Text('Предоставить доступ'),
              ),
            ),
          ],
        ),
      );
    }

    switch (cameraState.status) {
      case CameraStatus.uninitialized:
      case CameraStatus.initializing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Инициализация камеры...',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );

      case CameraStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  cameraState.errorMessage ?? 'Неизвестная ошибка',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Попробовать снова инициализацию камеры',
                  child: ElevatedButton(
                    onPressed: _initCamera,
                    child: const Text('Попробовать снова'),
                  ),
                ),
              ],
            ),
          ),
        );

      case CameraStatus.ready:
        final controller = cameraState.controller;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: Text(
              'Контроллер камеры не готов',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final isDetecting = ref.watch(isDetectingProvider);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview with proper aspect ratio
            _CameraPreviewWidget(controller: controller),

            // Bounding Boxes Overlay
            if (detectedObjects.isNotEmpty)
              ...detectedObjects.map(
                (obj) => _BoundingBoxWidget(
                  object: obj,
                  previewSize: controller.value.previewSize!,
                  screenSize: MediaQuery.of(context).size,
                ),
              ),

            // Streaming indicator
            if (cameraState.isStreaming)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDetecting
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDetecting ? Icons.sync : Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDetecting ? 'ANALYZING' : 'LIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned.fill(
              child: Semantics(
                label: 'Жестовая область управления',
                hint:
                    'Двойное касание переключает режим тишины. Долгое нажатие озвучивает сводку.',
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => unawaited(_handleDoubleTap()),
                  onLongPress: () => unawaited(_handleLongPress()),
                ),
              ),
            ),

            // Overlay label
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _buildOverlayStatus(
                    silenceEnabled: silenceEnabled,
                    objectCount: detectedObjects.length,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Widget to draw bounding boxes
class _BoundingBoxWidget extends StatelessWidget {
  final SimpleObject object;
  final Size previewSize;
  final Size screenSize;

  const _BoundingBoxWidget({
    required this.object,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    // ВАЖНО: Масштабирование координат
    // CameraImage обычно приходит в 640x480 (landscape).
    // На портретном экране previewSize.width = 640 (высота экрана),
    // previewSize.height = 480 (ширина экрана).

    final scaleX = screenSize.width / previewSize.height;
    final scaleY = screenSize.height / previewSize.width;

    final left = object.left * scaleX;
    final top = object.top * scaleY;
    final width = (object.right - object.left) * scaleX;
    final height = (object.bottom - object.top) * scaleY;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.greenAccent, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            color: Colors.greenAccent,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '${object.label} ${(object.confidence * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaledBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _ScaledBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

class _SpeakCandidate {
  final String key;
  final String text;
  final int distancePriority;
  final SpatialDistance distance;
  final double areaRatio;
  final double confidence;

  const _SpeakCandidate({
    required this.key,
    required this.text,
    required this.distancePriority,
    required this.distance,
    required this.areaRatio,
    required this.confidence,
  });
}

/// Helper widget to show camera preview with cover fit
class _CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            // Swap width/height for landscape-oriented previews on portrait devices
            width: controller.value.previewSize?.height ?? 480,
            height: controller.value.previewSize?.width ?? 640,
            child: controller.buildPreview(),
          ),
        ),
      ),
    );
  }
}
