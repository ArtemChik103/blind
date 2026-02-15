import 'dart:isolate';
import 'dart:typed_data';

/// Convert Android YUV_420_888 planes to NV21 bytes.
/// Input and output are isolate-safe via TransferableTypedData.
TransferableTypedData convertYuv420888ToNv21(Map<String, Object> msg) {
  final width = msg['width'] as int;
  final height = msg['height'] as int;
  final swapUV = (msg['swapUV'] as bool?) ?? false;

  final yTtd = msg['yBytes'] as TransferableTypedData;
  final uTtd = msg['uBytes'] as TransferableTypedData;
  final vTtd = msg['vBytes'] as TransferableTypedData;

  final yRowStride = msg['yRowStride'] as int;
  final uRowStride = msg['uRowStride'] as int;
  final vRowStride = msg['vRowStride'] as int;
  final uPixelStride = msg['uPixelStride'] as int;
  final vPixelStride = msg['vPixelStride'] as int;

  final yBytes = yTtd.materialize().asUint8List();
  final uBytes = uTtd.materialize().asUint8List();
  final vBytes = vTtd.materialize().asUint8List();

  final int ySize = width * height;
  final int uvSize = ySize ~/ 2;
  final Uint8List nv21 = Uint8List(ySize + uvSize);

  // Copy Y plane, row by row (handles rowStride padding).
  int yOutIndex = 0;
  for (int row = 0; row < height; row++) {
    final int rowStart = row * yRowStride;
    nv21.setRange(
      yOutIndex,
      yOutIndex + width,
      yBytes,
      rowStart,
    );
    yOutIndex += width;
  }

  // Interleave chroma. NV21 is VU, some devices need UV swap.
  int uvOutIndex = ySize;
  final int uvHeight = height ~/ 2;
  final int uvWidth = width ~/ 2;
  for (int row = 0; row < uvHeight; row++) {
    final int uRowStart = row * uRowStride;
    final int vRowStart = row * vRowStride;
    for (int col = 0; col < uvWidth; col++) {
      final int uIndex = uRowStart + col * uPixelStride;
      final int vIndex = vRowStart + col * vPixelStride;
      if (swapUV) {
        nv21[uvOutIndex++] = uBytes[uIndex];
        nv21[uvOutIndex++] = vBytes[vIndex];
      } else {
        nv21[uvOutIndex++] = vBytes[vIndex];
        nv21[uvOutIndex++] = uBytes[uIndex];
      }
    }
  }

  return TransferableTypedData.fromList([nv21]);
}
