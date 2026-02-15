import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/simple_object.dart';
import 'efficientdet_lite0_detector.dart';
import 'object_detection_isolate.dart';
import 'detection_provider.dart';
import 'yuv420_to_jpeg.dart';
import 'yuv420_to_nv21.dart';

/// Сервис для детекции объектов
class DetectionService {
  final Ref _ref;
  bool _isProcessing = false;
  bool _swapUv = false;
  int _zeroStreak = 0;

  DetectionService(this._ref);

  /// Обработать кадр камеры
  Future<void> processFrame(CameraImage image, int rotationDegrees) async {
    if (_isProcessing) return;
    _isProcessing = true;
    _ref.read(isDetectingProvider.notifier).state = true;

    try {
      if (_canUseTflite()) {
        try {
          final Uint8List jpegBytes = await _prepareJpegBytes(image);
          final results = await _ref.read(efficientDetLite0DetectorProvider).detectJpeg(
                jpegBytes: jpegBytes,
                rotationDegrees: rotationDegrees,
              );
          _ref.read(detectedObjectsProvider.notifier).state = results;
          return;
        } catch (e) {
          debugPrint('TFLite stream detection failed, fallback to ML Kit BASE: $e');
        }
      }

      final results = await _runMlKitBaseFallback(image, rotationDegrees);
      _ref.read(detectedObjectsProvider.notifier).state = results;
    } catch (e) {
      debugPrint('Detection error: $e');
      _ref.read(detectedObjectsProvider.notifier).state = [];
    } finally {
      _isProcessing = false;
      _ref.read(isDetectingProvider.notifier).state = false;
    }
  }

  bool _canUseTflite() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  Future<Uint8List> _prepareJpegBytes(CameraImage image) async {
    if (image.planes.length < 3) {
      throw StateError('Unsupported image format: ${image.planes.length} planes');
    }

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Map<String, Object> msg = <String, Object>{
      'width': image.width,
      'height': image.height,
      'quality': 85,
      'yBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(yPlane.bytes)],
      ),
      'yRowStride': yPlane.bytesPerRow,
      'uBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(uPlane.bytes)],
      ),
      'uRowStride': uPlane.bytesPerRow,
      'uPixelStride': uPlane.bytesPerPixel ?? 1,
      'vBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(vPlane.bytes)],
      ),
      'vRowStride': vPlane.bytesPerRow,
      'vPixelStride': vPlane.bytesPerPixel ?? 1,
    };

    final TransferableTypedData jpegTtd =
        await compute(convertYuv420888ToJpeg, msg);
    return jpegTtd.materialize().asUint8List();
  }

  Future<List<SimpleObject>> _runMlKitBaseFallback(
    CameraImage image,
    int rotationDegrees,
  ) async {
    final DetectionInput input = await _prepareMlKitInput(image, rotationDegrees);
    final List<SimpleObject> results = await runBaseObjectDetection(input);
    if (results.isEmpty) {
      _zeroStreak++;
      if (_zeroStreak >= 8) {
        _swapUv = !_swapUv;
        _zeroStreak = 0;
        debugPrint('Switching NV21 UV order: swapUV=$_swapUv');
      }
    } else {
      _zeroStreak = 0;
    }
    return results;
  }

  Future<DetectionInput> _prepareMlKitInput(
    CameraImage image,
    int rotationDegrees,
  ) async {
    if (image.planes.length < 3) {
      throw StateError('Unsupported image format: ${image.planes.length} planes');
    }

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final Map<String, Object> msg = <String, Object>{
      'width': image.width,
      'height': image.height,
      'swapUV': _swapUv,
      'yBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(yPlane.bytes)],
      ),
      'yRowStride': yPlane.bytesPerRow,
      'uBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(uPlane.bytes)],
      ),
      'uRowStride': uPlane.bytesPerRow,
      'uPixelStride': uPlane.bytesPerPixel ?? 1,
      'vBytes': TransferableTypedData.fromList(
        <TypedData>[Uint8List.fromList(vPlane.bytes)],
      ),
      'vRowStride': vPlane.bytesPerRow,
      'vPixelStride': vPlane.bytesPerPixel ?? 1,
    };

    final TransferableTypedData nv21Ttd =
        await compute(convertYuv420888ToNv21, msg);
    final Uint8List nv21Bytes = nv21Ttd.materialize().asUint8List();

    if (kDebugMode) {
      debugPrint(
        'NV21: ${image.width}x${image.height}, yRowStride=${yPlane.bytesPerRow}, '
        'uRowStride=${uPlane.bytesPerRow}, vRowStride=${vPlane.bytesPerRow}, '
        'uPixelStride=${uPlane.bytesPerPixel}, vPixelStride=${vPlane.bytesPerPixel}, '
        'bytes=${nv21Bytes.length}, swapUV=$_swapUv',
      );
    }

    return DetectionInput(
      bytes: nv21Bytes,
      width: image.width,
      height: image.height,
      rotation: rotationDegrees,
    );
  }

  Future<void> dispose() async {
    await closeDetector();
    await closeBaseDetector();
  }
}

final detectionServiceProvider = Provider<DetectionService>((ref) {
  final service = DetectionService(ref);
  ref.onDispose(service.dispose);
  return service;
});
