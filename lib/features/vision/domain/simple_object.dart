/// DTO для передачи результатов ML между изолятами
class SimpleObject {
  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const SimpleObject({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}
