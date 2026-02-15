import 'dart:typed_data';

import 'simple_object.dart';

abstract interface class LocalDetector {
  Future<List<SimpleObject>> detectJpeg({
    required Uint8List jpegBytes,
    required int rotationDegrees,
    double scoreThreshold,
  });

  Future<void> dispose();
}
