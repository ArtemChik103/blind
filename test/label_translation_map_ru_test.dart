import 'package:flutter_test/flutter_test.dart';
import 'package:sonar/features/vision/domain/label_translation_map_ru.dart';

void main() {
  test('translates required labels', () {
    expect(translateCocoLabelToRu('person'), 'человек');
    expect(translateCocoLabelToRu('chair'), 'стул');
    expect(translateCocoLabelToRu('table'), 'стол');
    expect(translateCocoLabelToRu('door'), 'дверь');
    expect(translateCocoLabelToRu('tv'), 'монитор');
    expect(translateCocoLabelToRu('laptop'), 'ноутбук');
  });

  test('normalizes label before lookup', () {
    expect(translateCocoLabelToRu(' Person '), 'человек');
  });

  test('translates base categories', () {
    expect(translateCocoLabelToRu('Home good'), 'предмет дома');
    expect(translateCocoLabelToRu('food'), 'еда');
  });

  test('falls back to raw label if unknown', () {
    expect(translateCocoLabelToRu('mystery'), 'mystery');
  });
}
