import 'dart:math' as math;

import 'coco_id_labelmap_en.dart';
import 'simple_object.dart';

class LetterboxTransform {
  final int inputSize;
  final int sourceWidth;
  final int sourceHeight;
  final double scale;
  final double padX;
  final double padY;

  const LetterboxTransform({
    required this.inputSize,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.scale,
    required this.padX,
    required this.padY,
  });
}

List<SimpleObject> postprocessEfficientDetDetections({
  required List<List<double>> boxes,
  required List<double> classes,
  required List<double> scores,
  required double scoreThreshold,
  required LetterboxTransform transform,
}) {
  if (transform.sourceWidth <= 0 ||
      transform.sourceHeight <= 0 ||
      transform.scale <= 0) {
    return const <SimpleObject>[];
  }

  final int maxCount = math.min(
    boxes.length,
    math.min(classes.length, scores.length),
  );
  if (maxCount <= 0) {
    return const <SimpleObject>[];
  }

  final double sourceWidth = transform.sourceWidth.toDouble();
  final double sourceHeight = transform.sourceHeight.toDouble();
  final double inputSize = transform.inputSize.toDouble();
  final List<SimpleObject> detections = <SimpleObject>[];

  for (int i = 0; i < maxCount; i++) {
    final double score = scores[i];
    if (score < scoreThreshold) {
      continue;
    }

    final List<double> rawBox = boxes[i];
    if (rawBox.length < 4) {
      continue;
    }

    final int classId = classes[i].round();
    final String label = cocoIdToLabelEn[classId] ?? 'object';

    final double ymin = _clamp(rawBox[0], 0.0, 1.0);
    final double xmin = _clamp(rawBox[1], 0.0, 1.0);
    final double ymax = _clamp(rawBox[2], 0.0, 1.0);
    final double xmax = _clamp(rawBox[3], 0.0, 1.0);

    final double leftInput = xmin * inputSize;
    final double topInput = ymin * inputSize;
    final double rightInput = xmax * inputSize;
    final double bottomInput = ymax * inputSize;

    final double left =
        _clamp((leftInput - transform.padX) / transform.scale, 0.0, sourceWidth);
    final double top =
        _clamp((topInput - transform.padY) / transform.scale, 0.0, sourceHeight);
    final double right =
        _clamp((rightInput - transform.padX) / transform.scale, 0.0, sourceWidth);
    final double bottom = _clamp(
      (bottomInput - transform.padY) / transform.scale,
      0.0,
      sourceHeight,
    );

    if (right <= left || bottom <= top) {
      continue;
    }

    detections.add(
      SimpleObject(
        label: label,
        confidence: score,
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
    );
  }

  return detections;
}

double _clamp(double value, double min, double max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
