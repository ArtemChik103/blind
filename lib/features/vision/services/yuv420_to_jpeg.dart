import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Convert Android YUV_420_888 planes to JPEG bytes in an isolate-safe way.
TransferableTypedData convertYuv420888ToJpeg(Map<String, Object> msg) {
  final int width = msg['width'] as int;
  final int height = msg['height'] as int;
  final int quality = (msg['quality'] as int?) ?? 85;

  final TransferableTypedData yTtd = msg['yBytes'] as TransferableTypedData;
  final TransferableTypedData uTtd = msg['uBytes'] as TransferableTypedData;
  final TransferableTypedData vTtd = msg['vBytes'] as TransferableTypedData;

  final int yRowStride = msg['yRowStride'] as int;
  final int uRowStride = msg['uRowStride'] as int;
  final int vRowStride = msg['vRowStride'] as int;
  final int uPixelStride = msg['uPixelStride'] as int;
  final int vPixelStride = msg['vPixelStride'] as int;

  final Uint8List yBytes = yTtd.materialize().asUint8List();
  final Uint8List uBytes = uTtd.materialize().asUint8List();
  final Uint8List vBytes = vTtd.materialize().asUint8List();

  final img.Image rgbImage = img.Image(
    width: width,
    height: height,
    numChannels: 3,
  );

  for (int y = 0; y < height; y++) {
    final int yRowStart = y * yRowStride;
    final int uvRow = y >> 1;
    final int uRowStart = uvRow * uRowStride;
    final int vRowStart = uvRow * vRowStride;

    for (int x = 0; x < width; x++) {
      final int yValue = yBytes[yRowStart + x];
      final int uvCol = x >> 1;
      final int uValue = uBytes[uRowStart + uvCol * uPixelStride];
      final int vValue = vBytes[vRowStart + uvCol * vPixelStride];

      final _Rgb rgb = _yuvToRgb(yValue, uValue, vValue);
      rgbImage.setPixelRgb(x, y, rgb.r, rgb.g, rgb.b);
    }
  }

  final Uint8List jpegBytes = Uint8List.fromList(
    img.encodeJpg(rgbImage, quality: quality),
  );
  return TransferableTypedData.fromList(<TypedData>[jpegBytes]);
}

_Rgb _yuvToRgb(int y, int u, int v) {
  final int c = y - 16;
  final int d = u - 128;
  final int e = v - 128;

  final int c1 = c < 0 ? 0 : c;
  final int r = ((298 * c1 + 409 * e + 128) >> 8).clamp(0, 255);
  final int g = ((298 * c1 - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
  final int b = ((298 * c1 + 516 * d + 128) >> 8).clamp(0, 255);

  return _Rgb(r: r, g: g, b: b);
}

class _Rgb {
  final int r;
  final int g;
  final int b;

  const _Rgb({
    required this.r,
    required this.g,
    required this.b,
  });
}
