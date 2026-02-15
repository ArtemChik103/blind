import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../domain/coco_labelmap.dart';
import '../domain/simple_object.dart';
import 'local_object_model_loader.dart';

/// Данные для передачи в isolate
class DetectionInput {
  final Uint8List bytes;
  final int width;
  final int height;
  final int rotation; // 0, 90, 180, 270

  const DetectionInput({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotation,
  });
}

ObjectDetector? _detector;
ObjectDetector? _baseDetector;
bool _usingLocalModel = false;
bool _forceBaseModel = false;
bool _loggedDetectorType = false;
bool _loggedLabelFallback = false;
String? _localModelPath;

void _logDetectorType({String? modelPath}) {
  if (_loggedDetectorType) return;
  if (_usingLocalModel) {
    final effectivePath = modelPath ?? _localModelPath;
    final suffix = effectivePath == null ? '' : ' path=$effectivePath';
    debugPrint('ObjectDetector: using LOCAL model$suffix');
  } else {
    debugPrint('ObjectDetector: using BASE model');
  }
  _loggedDetectorType = true;
}

bool _isGenericLabel(String text) {
  switch (text) {
    case 'object':
    case 'other':
    case 'unknown':
    case 'home good':
    case 'fashion good':
    case 'food':
    case 'place':
      return true;
  }
  return false;
}

String _labelFromIndex(int index, List<String> labels) {
  if (labels.isEmpty) return '';
  if (index >= 0 && index < labels.length) {
    return labels[index];
  }
  final shifted = index - 1;
  if (shifted >= 0 && shifted < labels.length) {
    return labels[shifted];
  }
  return '';
}

Future<ObjectDetector> _getDetector() async {
  final existing = _detector;
  if (existing != null) {
    if (!_usingLocalModel && !_forceBaseModel) {
      final modelPath = await LocalObjectModelLoader.prepareLocalModelPath();
      if (modelPath != null) {
        await closeDetector();
        _usingLocalModel = true;
        _localModelPath = modelPath;
        _detector = ObjectDetector(
          options: LocalObjectDetectorOptions(
            mode: DetectionMode.single,
            modelPath: modelPath,
            classifyObjects: true,
            multipleObjects: true,
            maximumLabelsPerObject: 1,
            confidenceThreshold: 0.2,
          ),
        );
        _logDetectorType(modelPath: modelPath);
        return _detector!;
      }
    }
    return existing;
  }

  if (!_forceBaseModel) {
    final modelPath = await LocalObjectModelLoader.prepareLocalModelPath();
    if (modelPath != null) {
      _usingLocalModel = true;
      _localModelPath = modelPath;
      _detector = ObjectDetector(
        options: LocalObjectDetectorOptions(
          mode: DetectionMode.single,
          modelPath: modelPath,
          classifyObjects: true,
          multipleObjects: true,
          maximumLabelsPerObject: 1,
          confidenceThreshold: 0.2,
        ),
      );
    }
  }

  _detector ??= ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );

  _logDetectorType();

  return _detector!;
}

/// TOP-LEVEL FUNCTION
Future<List<SimpleObject>> runObjectDetection(DetectionInput input) async {
  try {
    final inputImageRotation = _rotationFromInt(input.rotation);

    final inputImage = InputImage.fromBytes(
      bytes: input.bytes,
      metadata: InputImageMetadata(
        size: Size(input.width.toDouble(), input.height.toDouble()),
        rotation: inputImageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: input.width,
      ),
    );

    ObjectDetector detector = await _getDetector();

    List<DetectedObject> objects;
    try {
      objects = await detector.processImage(inputImage);
    } catch (e) {
      if (_usingLocalModel && !_forceBaseModel) {
        _forceBaseModel = true;
        await closeDetector();
        detector = await _getDetector();
        objects = await detector.processImage(inputImage);
      } else {
        rethrow;
      }
    }

    debugPrint('=== DETECTION ===');
    debugPrint('Objects found: ${objects.length}');
    for (final obj in objects) {
      debugPrint(
        '  - ${obj.labels.map((l) => l.text).join(", ")} @ ${obj.boundingBox}',
      );
    }

    final cocoLabels =
        _usingLocalModel ? await loadCocoLabels() : const <String>[];

    final List<SimpleObject> results = objects.map((obj) {
      String label = 'Объект';
      double confidence = 0.0;

      if (obj.labels.isNotEmpty) {
        final bestLabel = obj.labels.reduce(
          (a, b) => a.confidence > b.confidence ? a : b,
        );
        label = bestLabel.text.trim();
        confidence = bestLabel.confidence;
        if (_usingLocalModel) {
          final normalized = label.toLowerCase();
          if (label.isEmpty || _isGenericLabel(normalized)) {
            final fromIndex = _labelFromIndex(bestLabel.index, cocoLabels);
            if (fromIndex.isNotEmpty) {
              label = fromIndex;
              if (!_loggedLabelFallback) {
                debugPrint('Label fallback by index: $label');
                _loggedLabelFallback = true;
              }
            }
          }
        }
      }
      if (label.isEmpty) {
        label = 'Объект';
      }

      return SimpleObject(
        label: label,
        confidence: confidence,
        left: obj.boundingBox.left,
        top: obj.boundingBox.top,
        right: obj.boundingBox.right,
        bottom: obj.boundingBox.bottom,
      );
    }).toList();

    return results;
  } catch (e) {
    debugPrint('ML Detection Error: $e');
    return [];
  }
}

Future<List<SimpleObject>> runBaseObjectDetection(DetectionInput input) async {
  try {
    final inputImageRotation = _rotationFromInt(input.rotation);

    final inputImage = InputImage.fromBytes(
      bytes: input.bytes,
      metadata: InputImageMetadata(
        size: Size(input.width.toDouble(), input.height.toDouble()),
        rotation: inputImageRotation,
        format: InputImageFormat.nv21,
        bytesPerRow: input.width,
      ),
    );

    final ObjectDetector detector = _baseDetector ??= ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );

    final List<DetectedObject> objects = await detector.processImage(inputImage);
    return _mapDetectedObjects(objects);
  } catch (e) {
    debugPrint('ML BASE Detection Error: $e');
    return [];
  }
}

List<SimpleObject> _mapDetectedObjects(List<DetectedObject> objects) {
  return objects.map((obj) {
    String label = 'Объект';
    double confidence = 0.0;

    if (obj.labels.isNotEmpty) {
      final bestLabel = obj.labels.reduce(
        (a, b) => a.confidence > b.confidence ? a : b,
      );
      label = bestLabel.text.trim();
      confidence = bestLabel.confidence;
    }
    if (label.isEmpty) {
      label = 'Объект';
    }

    return SimpleObject(
      label: label,
      confidence: confidence,
      left: obj.boundingBox.left,
      top: obj.boundingBox.top,
      right: obj.boundingBox.right,
      bottom: obj.boundingBox.bottom,
    );
  }).toList();
}

Future<void> closeDetector() async {
  final detector = _detector;
  if (detector != null) {
    await detector.close();
    _detector = null;
  }
  _usingLocalModel = false;
  _loggedDetectorType = false;
  _localModelPath = null;
}

Future<void> closeBaseDetector() async {
  final ObjectDetector? detector = _baseDetector;
  if (detector != null) {
    await detector.close();
    _baseDetector = null;
  }
}

InputImageRotation _rotationFromInt(int rotation) {
  switch (rotation) {
    case 0:
      return InputImageRotation.rotation0deg;
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    case 270:
      return InputImageRotation.rotation270deg;
    default:
      return InputImageRotation.rotation0deg;
  }
}
