import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LocalObjectModelLoader {
  static const String assetPath = 'assets/models/efficientdet_lite0.tflite';
  static const String _fileName = 'efficientdet_lite0.tflite';
  static const int _minBytes = 100000;

  static Future<String?>? _cachedPathFuture;

  static Future<String?> prepareLocalModelPath() {
    return _cachedPathFuture ??= _prepare();
  }

  static Future<String?> _prepare() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}mlkit_models',
    );
    final modelFile = File(
      '${modelDir.path}${Platform.pathSeparator}$_fileName',
    );

    if (await modelFile.exists()) {
      final length = await modelFile.length();
      if (length >= _minBytes) {
        return modelFile.path;
      }
    }

    ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } on FlutterError {
      return null;
    }

    if (data.lengthInBytes < _minBytes) {
      return null;
    }

    await modelDir.create(recursive: true);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await modelFile.writeAsBytes(bytes, flush: true);
    return modelFile.path;
  }
}
