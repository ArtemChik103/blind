import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/efficientdet_postprocess.dart';
import '../domain/simple_object.dart';

const int _inputSize = 320;
const int _maxDetections = 25;

Future<void> tfliteIsolateWorkerMain(SendPort bootstrapSendPort) async {
  final ReceivePort commandPort = ReceivePort();
  bootstrapSendPort.send(commandPort.sendPort);

  Interpreter? interpreter;

  await for (final Object? rawMessage in commandPort) {
    if (rawMessage is! Map<Object?, Object?>) {
      continue;
    }

    final String command = _stringField(rawMessage, 'type');

    if (command == 'dispose') {
      interpreter?.close();
      commandPort.close();
      return;
    }

    final SendPort replyPort = _sendPortField(rawMessage, 'replyPort');
    final int requestId = _intField(rawMessage, 'requestId');

    try {
      switch (command) {
        case 'init':
          interpreter?.close();
          interpreter = _initInterpreter(rawMessage);
          replyPort.send(
            <String, Object>{
              'requestId': requestId,
              'ok': true,
            },
          );
          break;
        case 'detectJpeg':
          final Interpreter initializedInterpreter = interpreter ??
              (throw StateError('Worker is not initialized'));
          final Map<String, Object> result = _detectJpeg(
            initializedInterpreter,
            rawMessage,
          );
          replyPort.send(
            <String, Object>{
              'requestId': requestId,
              'ok': true,
              ...result,
            },
          );
          break;
        default:
          throw UnsupportedError('Unknown worker command: $command');
      }
    } catch (error, stackTrace) {
      replyPort.send(
        <String, Object>{
          'requestId': requestId,
          'ok': false,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }
}

Interpreter _initInterpreter(Map<Object?, Object?> message) {
  final TransferableTypedData modelData =
      _transferableDataField(message, 'modelBytes');
  final Uint8List modelBytes = modelData.materialize().asUint8List();
  final int threads = _intField(message, 'threads');

  final InterpreterOptions options = InterpreterOptions()..threads = threads;
  return Interpreter.fromBuffer(modelBytes, options: options);
}

Map<String, Object> _detectJpeg(
  Interpreter interpreter,
  Map<Object?, Object?> message,
) {
  final TransferableTypedData jpegData =
      _transferableDataField(message, 'jpegBytes');
  final Uint8List jpegBytes = jpegData.materialize().asUint8List();
  final int rotationDegrees = _intField(message, 'rotationDegrees');
  final double scoreThreshold = _doubleField(message, 'scoreThreshold');

  final Stopwatch totalStopwatch = Stopwatch()..start();

  final Stopwatch preprocessStopwatch = Stopwatch()..start();
  final _PreparedImage prepared = _prepareImage(
    jpegBytes: jpegBytes,
    rotationDegrees: rotationDegrees,
  );
  preprocessStopwatch.stop();

  final Stopwatch inferenceStopwatch = Stopwatch()..start();
  final _InferenceResult inference = _runInference(
    interpreter: interpreter,
    inputTensor: prepared.inputTensor,
  );
  inferenceStopwatch.stop();

  final List<SimpleObject> detections = postprocessEfficientDetDetections(
    boxes: inference.boxes,
    classes: inference.classes,
    scores: inference.scores,
    scoreThreshold: scoreThreshold,
    transform: LetterboxTransform(
      inputSize: _inputSize,
      sourceWidth: prepared.sourceWidth,
      sourceHeight: prepared.sourceHeight,
      scale: prepared.scale,
      padX: prepared.padX,
      padY: prepared.padY,
    ),
  );

  totalStopwatch.stop();

  return <String, Object>{
    'detections': detections
        .map(
          (SimpleObject detection) => <String, Object>{
            'label': detection.label,
            'confidence': detection.confidence,
            'left': detection.left,
            'top': detection.top,
            'right': detection.right,
            'bottom': detection.bottom,
          },
        )
        .toList(growable: false),
    'imageWidth': prepared.sourceWidth,
    'imageHeight': prepared.sourceHeight,
    'preprocessMs': preprocessStopwatch.elapsedMilliseconds,
    'inferenceMs': inferenceStopwatch.elapsedMilliseconds,
    'totalMs': totalStopwatch.elapsedMilliseconds,
  };
}

_PreparedImage _prepareImage({
  required Uint8List jpegBytes,
  required int rotationDegrees,
}) {
  final img.Image decoded =
      img.decodeJpg(jpegBytes) ?? (throw StateError('Failed to decode JPEG'));
  final img.Image rotated = _rotateImage(decoded, rotationDegrees);

  final int sourceWidth = rotated.width;
  final int sourceHeight = rotated.height;
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw StateError('Invalid image size: ${sourceWidth}x$sourceHeight');
  }

  final double scale = math.min(
    _inputSize / sourceWidth.toDouble(),
    _inputSize / sourceHeight.toDouble(),
  );
  final int resizedWidth = math.max(1, (sourceWidth * scale).round());
  final int resizedHeight = math.max(1, (sourceHeight * scale).round());
  final int padX = ((_inputSize - resizedWidth) / 2).floor();
  final int padY = ((_inputSize - resizedHeight) / 2).floor();

  final img.Image resized = img.copyResize(
    rotated,
    width: resizedWidth,
    height: resizedHeight,
    interpolation: img.Interpolation.linear,
  );

  final img.Image letterboxed = img.Image(
    width: _inputSize,
    height: _inputSize,
    numChannels: 3,
  );
  img.fill(letterboxed, color: img.ColorRgb8(127, 127, 127));
  img.compositeImage(letterboxed, resized, dstX: padX, dstY: padY);

  final Uint8List inputTensor = Uint8List(_inputSize * _inputSize * 3);
  int offset = 0;
  for (int y = 0; y < _inputSize; y++) {
    for (int x = 0; x < _inputSize; x++) {
      final img.Pixel pixel = letterboxed.getPixel(x, y);
      inputTensor[offset++] = pixel.r.toInt();
      inputTensor[offset++] = pixel.g.toInt();
      inputTensor[offset++] = pixel.b.toInt();
    }
  }

  return _PreparedImage(
    inputTensor: inputTensor,
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    scale: resizedWidth / sourceWidth,
    padX: padX.toDouble(),
    padY: padY.toDouble(),
  );
}

_InferenceResult _runInference({
  required Interpreter interpreter,
  required Uint8List inputTensor,
}) {
  final List<List<List<double>>> boxesOutput = List<List<List<double>>>.generate(
    1,
    (_) => List<List<double>>.generate(
      _maxDetections,
      (_) => List<double>.filled(4, 0.0, growable: false),
      growable: false,
    ),
    growable: false,
  );
  final List<List<double>> classesOutput = List<List<double>>.generate(
    1,
    (_) => List<double>.filled(_maxDetections, 0.0, growable: false),
    growable: false,
  );
  final List<List<double>> scoresOutput = List<List<double>>.generate(
    1,
    (_) => List<double>.filled(_maxDetections, 0.0, growable: false),
    growable: false,
  );
  final List<double> numOutput = List<double>.filled(1, 0.0, growable: false);

  interpreter.runForMultipleInputs(
    <Object>[inputTensor],
    <int, Object>{
      0: boxesOutput,
      1: classesOutput,
      2: scoresOutput,
      3: numOutput,
    },
  );

  return _InferenceResult(
    boxes: boxesOutput.first,
    classes: classesOutput.first,
    scores: scoresOutput.first,
  );
}

img.Image _rotateImage(img.Image image, int rotationDegrees) {
  final int normalized = rotationDegrees % 360;
  switch (normalized) {
    case 0:
      return image;
    case 90:
      return img.copyRotate(image, angle: 90);
    case 180:
      return img.copyRotate(image, angle: 180);
    case 270:
      return img.copyRotate(image, angle: 270);
    default:
      throw ArgumentError('rotationDegrees must be 0/90/180/270');
  }
}

String _stringField(Map<Object?, Object?> message, String key) {
  final Object? value = message[key];
  if (value is String) {
    return value;
  }
  throw StateError('Expected String for "$key", got $value');
}

int _intField(Map<Object?, Object?> message, String key) {
  final Object? value = message[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw StateError('Expected int for "$key", got $value');
}

double _doubleField(Map<Object?, Object?> message, String key) {
  final Object? value = message[key];
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw StateError('Expected double for "$key", got $value');
}

SendPort _sendPortField(Map<Object?, Object?> message, String key) {
  final Object? value = message[key];
  if (value is SendPort) {
    return value;
  }
  throw StateError('Expected SendPort for "$key", got $value');
}

TransferableTypedData _transferableDataField(
  Map<Object?, Object?> message,
  String key,
) {
  final Object? value = message[key];
  if (value is TransferableTypedData) {
    return value;
  }
  throw StateError('Expected TransferableTypedData for "$key", got $value');
}

class _PreparedImage {
  final Uint8List inputTensor;
  final int sourceWidth;
  final int sourceHeight;
  final double scale;
  final double padX;
  final double padY;

  const _PreparedImage({
    required this.inputTensor,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}

class _InferenceResult {
  final List<List<double>> boxes;
  final List<double> classes;
  final List<double> scores;

  const _InferenceResult({
    required this.boxes,
    required this.classes,
    required this.scores,
  });
}
