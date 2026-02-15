enum SpatialDirection { left, center, right }

enum SpatialDistance { close, near }

class SpatialDescription {
  final SpatialDirection direction;
  final SpatialDistance distance;

  const SpatialDescription({
    required this.direction,
    required this.distance,
  });
}

class SpatialCalculator {
  const SpatialCalculator();

  static SpatialDescription? describe({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double screenWidth,
    required double screenHeight,
  }) {
    if (screenWidth <= 0 || screenHeight <= 0) {
      return null;
    }

    final centerX = (left + right) / 2;
    final direction = _directionFor(centerX, screenWidth);

    final boxArea = (right - left) * (bottom - top);
    final screenArea = screenWidth * screenHeight;
    if (boxArea <= 0 || screenArea <= 0) {
      return null;
    }

    final ratio = boxArea / screenArea;
    final distance = _distanceFor(ratio);
    if (distance == null) {
      return null;
    }

    return SpatialDescription(direction: direction, distance: distance);
  }

  static SpatialDirection _directionFor(double centerX, double width) {
    if (centerX < width * 0.3) {
      return SpatialDirection.left;
    }
    if (centerX > width * 0.7) {
      return SpatialDirection.right;
    }
    return SpatialDirection.center;
  }

  static SpatialDistance? _distanceFor(double ratio) {
    if (ratio > 0.6) {
      return SpatialDistance.close;
    }
    if (ratio > 0.2) {
      return SpatialDistance.near;
    }
    return null;
  }

  static String directionToRu(SpatialDirection direction) {
    return switch (direction) {
      SpatialDirection.left => 'Слева',
      SpatialDirection.center => 'Прямо',
      SpatialDirection.right => 'Справа',
    };
  }

  static String distanceToRu(SpatialDistance distance) {
    return switch (distance) {
      SpatialDistance.close => 'Вплотную',
      SpatialDistance.near => 'Рядом',
    };
  }
}
