import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/local_detector.dart';
import '../domain/simple_object.dart';
import 'tflite_isolate_worker.dart';

class LocalDetectionPerfInfo {
  final int imageWidth;
  final int imageHeight;
  final int preprocessMs;
  final int inferenceMs;
  final int totalMs;

  const LocalDetectionPerfInfo({
    required this.imageWidth,
    required this.imageHeight,
    required this.preprocessMs,
    required this.inferenceMs,
    required this.totalMs,
  });
}

class EfficientDetLite0Detector implements LocalDetector {
  static const String _modelAssetPath = 'assets/models/efficientdet_lite0.tflite';

  final int _threads;
  final double _defaultScoreThreshold;

  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _responsePort;
  StreamSubscription<Object?>? _responseSub;
  Future<void>? _initFuture;
  bool _isDisposed = false;
  int _nextRequestId = 0;
  final Map<int, Completer<Map<Object?, Object?>>> _pending =
      <int, Completer<Map<Object?, Object?>>>{};

  LocalDetectionPerfInfo? _lastPerfInfo;
  LocalDetectionPerfInfo? get lastPerfInfo => _lastPerfInfo;

  EfficientDetLite0Detector({
    int threads = 2,
    double defaultScoreThreshold = 0.35,
  })  : _threads = threads,
        _defaultScoreThreshold = defaultScoreThreshold;

  @override
  Future<List<SimpleObject>> detectJpeg({
    required Uint8List jpegBytes,
    required int rotationDegrees,
    double scoreThreshold = 0.35,
  }) async {
    if (_isDisposed) {
      throw StateError('Detector is already disposed');
    }
    if (jpegBytes.isEmpty) {
      return const <SimpleObject>[];
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const <SimpleObject>[];
    }

    await _ensureInitialized();

    final Map<Object?, Object?> response = await _sendRequest(
      type: 'detectJpeg',
      payload: <String, Object>{
        'jpegBytes': TransferableTypedData.fromList(<TypedData>[jpegBytes]),
        'rotationDegrees': rotationDegrees,
        'scoreThreshold': scoreThreshold > 0 ? scoreThreshold : _defaultScoreThreshold,
      },
    );

    final Object? detectionsRaw = response['detections'];
    final List<SimpleObject> detections = <SimpleObject>[];
    if (detectionsRaw is List<Object?>) {
      for (final Object? item in detectionsRaw) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        final String label = _stringOrDefault(item, 'label', 'object');
        final double confidence = _doubleOrDefault(item, 'confidence', 0.0);
        final double left = _doubleOrDefault(item, 'left', 0.0);
        final double top = _doubleOrDefault(item, 'top', 0.0);
        final double right = _doubleOrDefault(item, 'right', 0.0);
        final double bottom = _doubleOrDefault(item, 'bottom', 0.0);

        detections.add(
          SimpleObject(
            label: label,
            confidence: confidence,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
        );
      }
    }

    final LocalDetectionPerfInfo info = LocalDetectionPerfInfo(
      imageWidth: _intOrDefault(response, 'imageWidth', 0),
      imageHeight: _intOrDefault(response, 'imageHeight', 0),
      preprocessMs: _intOrDefault(response, 'preprocessMs', 0),
      inferenceMs: _intOrDefault(response, 'inferenceMs', 0),
      totalMs: _intOrDefault(response, 'totalMs', 0),
    );
    _lastPerfInfo = info;
    if (kDebugMode) {
      debugPrint(
        'TFLite snapshot timings: preprocess=${info.preprocessMs}ms, '
        'inference=${info.inferenceMs}ms, total=${info.totalMs}ms, '
        'image=${info.imageWidth}x${info.imageHeight}, detections=${detections.length}',
      );
    }

    return detections;
  }

  Future<void> _ensureInitialized() async {
    final Future<void>? inProgress = _initFuture;
    if (inProgress != null) {
      return inProgress;
    }
    final Future<void> created = _initializeWorker();
    _initFuture = created;
    try {
      await created;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _initializeWorker() async {
    final ReceivePort readyPort = ReceivePort();
    _workerIsolate = await Isolate.spawn<SendPort>(
      tfliteIsolateWorkerMain,
      readyPort.sendPort,
      debugName: 'efficientdet_lite0_worker',
    );

    final Object? bootstrapMessage = await readyPort.first;
    readyPort.close();

    if (bootstrapMessage is! SendPort) {
      throw StateError('Worker failed to send SendPort bootstrap message');
    }
    _workerSendPort = bootstrapMessage;

    _responsePort = ReceivePort();
    _responseSub = _responsePort!.listen(_handleWorkerResponse);

    final ByteData modelData = await rootBundle.load(_modelAssetPath);
    final Uint8List modelBytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );

    await _sendRequest(
      type: 'init',
      payload: <String, Object>{
        'modelBytes': TransferableTypedData.fromList(<TypedData>[modelBytes]),
        'threads': _threads,
      },
    );
  }

  Future<Map<Object?, Object?>> _sendRequest({
    required String type,
    required Map<String, Object> payload,
  }) async {
    final SendPort sendPort = _workerSendPort ??
        (throw StateError('Worker SendPort is not initialized'));
    final ReceivePort responsePort = _responsePort ??
        (throw StateError('Response port is not initialized'));
    final int requestId = _nextRequestId++;

    final Completer<Map<Object?, Object?>> completer =
        Completer<Map<Object?, Object?>>();
    _pending[requestId] = completer;

    final Map<String, Object> request = <String, Object>{
      'type': type,
      'requestId': requestId,
      'replyPort': responsePort.sendPort,
      ...payload,
    };
    sendPort.send(request);

    final Map<Object?, Object?> response = await completer.future;
    final bool ok = response['ok'] == true;
    if (!ok) {
      final Object? error = response['error'];
      throw StateError(error?.toString() ?? 'Unknown worker error');
    }
    return response;
  }

  void _handleWorkerResponse(Object? message) {
    if (message is! Map<Object?, Object?>) {
      return;
    }
    final Object? requestIdRaw = message['requestId'];
    if (requestIdRaw is! int) {
      return;
    }
    final Completer<Map<Object?, Object?>>? completer =
        _pending.remove(requestIdRaw);
    if (completer == null || completer.isCompleted) {
      return;
    }
    completer.complete(message);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    final SendPort? sendPort = _workerSendPort;
    if (sendPort != null) {
      sendPort.send(<String, Object>{'type': 'dispose'});
    }

    for (final Completer<Map<Object?, Object?>> pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Detector disposed before response'));
      }
    }
    _pending.clear();

    await _responseSub?.cancel();
    _responseSub = null;

    _responsePort?.close();
    _responsePort = null;

    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _initFuture = null;
  }
}

final efficientDetLite0DetectorProvider = Provider<EfficientDetLite0Detector>((
  ref,
) {
  final EfficientDetLite0Detector detector = EfficientDetLite0Detector();
  ref.onDispose(() {
    unawaited(detector.dispose());
  });
  return detector;
});

String _stringOrDefault(
  Map<Object?, Object?> map,
  String key,
  String defaultValue,
) {
  final Object? value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return defaultValue;
}

double _doubleOrDefault(
  Map<Object?, Object?> map,
  String key,
  double defaultValue,
) {
  final Object? value = map[key];
  if (value is num) {
    return value.toDouble();
  }
  return defaultValue;
}

int _intOrDefault(
  Map<Object?, Object?> map,
  String key,
  int defaultValue,
) {
  final Object? value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return defaultValue;
}
