import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String _assetPath = 'assets/models/coco_labels_en.txt';

Future<List<String>>? _cachedLabelsFuture;

Future<List<String>> loadCocoLabels() {
  return _cachedLabelsFuture ??= _load();
}

Future<List<String>> _load() async {
  try {
    final data = await rootBundle.loadString(_assetPath);
    final lines = data.split(RegExp(r'\r?\n'));
    final labels = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        labels.add(trimmed);
      }
    }
    return labels;
  } on FlutterError {
    return const <String>[];
  }
}
