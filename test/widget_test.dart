// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sonar/main.dart';
import 'package:sonar/core/constants/app_strings.dart';
import 'package:sonar/core/services/shared_prefs_service.dart';

void main() {
  testWidgets('Shows warning screen by default', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const SonarApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppStrings.warningTitle), findsOneWidget);
    final buttonFinder = find.widgetWithText(
      ElevatedButton,
      AppStrings.startSonar,
    );
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);
  });
}
