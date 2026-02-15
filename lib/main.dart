import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/shared_prefs_service.dart';
import 'features/safety/presentation/warning_screen.dart';
import 'features/vision/presentation/camera_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SonarApp(),
    ),
  );
}

class SonarApp extends ConsumerWidget {
  const SonarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAcceptedRisks = ref.watch(riskAcceptanceProvider);

    return MaterialApp(
      title: 'Sonar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Initial route based on risk acceptance
      home: hasAcceptedRisks ? const CameraScreen() : const WarningScreen(),
      routes: {
        '/warning': (context) => const WarningScreen(),
        '/camera': (context) => const CameraScreen(),
      },
    );
  }
}
