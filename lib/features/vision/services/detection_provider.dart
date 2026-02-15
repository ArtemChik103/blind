import 'package:flutter_riverpod/legacy.dart';
import '../domain/simple_object.dart';

/// Провайдер для хранения результатов детекции
final detectedObjectsProvider = StateProvider<List<SimpleObject>>((ref) => []);

/// Провайдер для статуса детекции
final isDetectingProvider = StateProvider<bool>((ref) => false);
