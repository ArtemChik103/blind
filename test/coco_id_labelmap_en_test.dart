import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/features/vision/domain/coco_id_labelmap_en.dart';

void main() {
  test('maps required COCO IDs', () {
    expect(cocoIdToLabelEn[1], 'person');
    expect(cocoIdToLabelEn[86], 'vase');
    expect(cocoIdToLabelEn[90], 'toothbrush');
  });

  test('does not include missing ids', () {
    expect(cocoIdToLabelEn.containsKey(12), isFalse);
    expect(cocoIdToLabelEn.containsKey(83), isFalse);
  });
}
