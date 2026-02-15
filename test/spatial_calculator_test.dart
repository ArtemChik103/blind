import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/features/vision/domain/spatial_calculator.dart';

void main() {
  test('direction thresholds', () {
    const screenWidth = 100.0;
    const screenHeight = 100.0;

    final leftDesc = SpatialCalculator.describe(
      left: 0,
      top: 0,
      right: 50,
      bottom: 60,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(leftDesc?.direction, SpatialDirection.left);

    final centerDesc = SpatialCalculator.describe(
      left: 20,
      top: 0,
      right: 80,
      bottom: 60,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(centerDesc?.direction, SpatialDirection.center);

    final rightDesc = SpatialCalculator.describe(
      left: 50,
      top: 0,
      right: 100,
      bottom: 60,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(rightDesc?.direction, SpatialDirection.right);
  });

  test('distance thresholds', () {
    const screenWidth = 100.0;
    const screenHeight = 100.0;

    final closeDesc = SpatialCalculator.describe(
      left: 0,
      top: 0,
      right: 78.1,
      bottom: 78.1,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(closeDesc?.distance, SpatialDistance.close);

    final nearDesc = SpatialCalculator.describe(
      left: 0,
      top: 0,
      right: 45.8,
      bottom: 45.8,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(nearDesc?.distance, SpatialDistance.near);

    final farDesc = SpatialCalculator.describe(
      left: 0,
      top: 0,
      right: 43.6,
      bottom: 43.6,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
    expect(farDesc, isNull);
  });
}
