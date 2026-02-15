import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonar/features/vision/services/yuv420_to_nv21.dart';

void main() {
  test('convertYuv420888ToNv21 handles padding and strides', () {
    const width = 4;
    const height = 2;

    final yBytes = Uint8List.fromList([
      1, 2, 3, 4, 9, 9, // row 0 (stride 6)
      5, 6, 7, 8, 9, 9, // row 1 (stride 6)
    ]);

    final uBytes = Uint8List.fromList([
      10, 0, 11, 0, // stride 4, pixelStride 2
    ]);

    final vBytes = Uint8List.fromList([
      20, 0, 21, 0, // stride 4, pixelStride 2
    ]);

    final msg = <String, Object>{
      'width': width,
      'height': height,
      'yBytes': TransferableTypedData.fromList([yBytes]),
      'yRowStride': 6,
      'uBytes': TransferableTypedData.fromList([uBytes]),
      'uRowStride': 4,
      'uPixelStride': 2,
      'vBytes': TransferableTypedData.fromList([vBytes]),
      'vRowStride': 4,
      'vPixelStride': 2,
    };

    final ttd = convertYuv420888ToNv21(msg);
    final nv21 = ttd.materialize().asUint8List();

    expect(nv21.length, 12);
    expect(nv21.sublist(0, 8), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(nv21.sublist(8, 12), [20, 10, 21, 11]);
  });

  test('convertYuv420888ToNv21 supports UV swap', () {
    const width = 4;
    const height = 2;

    final yBytes = Uint8List.fromList([
      1, 2, 3, 4, 9, 9,
      5, 6, 7, 8, 9, 9,
    ]);

    final uBytes = Uint8List.fromList([
      10, 0, 11, 0,
    ]);

    final vBytes = Uint8List.fromList([
      20, 0, 21, 0,
    ]);

    final msg = <String, Object>{
      'width': width,
      'height': height,
      'swapUV': true,
      'yBytes': TransferableTypedData.fromList([yBytes]),
      'yRowStride': 6,
      'uBytes': TransferableTypedData.fromList([uBytes]),
      'uRowStride': 4,
      'uPixelStride': 2,
      'vBytes': TransferableTypedData.fromList([vBytes]),
      'vRowStride': 4,
      'vPixelStride': 2,
    };

    final ttd = convertYuv420888ToNv21(msg);
    final nv21 = ttd.materialize().asUint8List();

    expect(nv21.length, 12);
    expect(nv21.sublist(8, 12), [10, 20, 11, 21]);
  });
}
