import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/features/vision/domain/efficientdet_postprocess.dart';

void main() {
  test('clamps box and maps from letterbox coords to source coords', () {
    const transform = LetterboxTransform(
      inputSize: 320,
      sourceWidth: 640,
      sourceHeight: 480,
      scale: 0.5,
      padX: 0,
      padY: 40,
    );

    final detections = postprocessEfficientDetDetections(
      boxes: const <List<double>>[
        <double>[-0.2, -0.1, 1.2, 1.1],
      ],
      classes: const <double>[1],
      scores: const <double>[0.95],
      scoreThreshold: 0.35,
      transform: transform,
    );

    expect(detections, hasLength(1));
    final detection = detections.first;
    expect(detection.label, 'person');
    expect(detection.left, 0);
    expect(detection.top, 0);
    expect(detection.right, 640);
    expect(detection.bottom, 480);
  });

  test('rounds class id and applies score threshold', () {
    const transform = LetterboxTransform(
      inputSize: 320,
      sourceWidth: 320,
      sourceHeight: 320,
      scale: 1,
      padX: 0,
      padY: 0,
    );

    final detections = postprocessEfficientDetDetections(
      boxes: const <List<double>>[
        <double>[0.1, 0.1, 0.6, 0.6],
        <double>[0.2, 0.2, 0.4, 0.4],
      ],
      classes: const <double>[86.4, 90.0],
      scores: const <double>[0.7, 0.2],
      scoreThreshold: 0.35,
      transform: transform,
    );

    expect(detections, hasLength(1));
    expect(detections.first.label, 'vase');
  });
}
