import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sortie_ui/sortie_ui.dart';

void main() {
  group('SortieTheme & SortiePrimaryButton tests', () {
    test('SortieTheme.lightTheme elevatedButtonTheme has finite minimumSize', () {
      final theme = SortieTheme.lightTheme;
      final btnStyle = theme.elevatedButtonTheme.style;
      final minSize = btnStyle?.minimumSize?.resolve({});

      expect(minSize, isNotNull);
      expect(minSize!.width.isFinite, isTrue,
          reason: 'minimumSize width must be finite, never double.infinity');
      expect(minSize.height, greaterThanOrEqualTo(48.0),
          reason: 'minimumSize height must respect touch target >= 48dp');
    });

    testWidgets('SortiePrimaryButton renders in bounded constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SortieTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: SortiePrimaryButton(
                  label: 'Valider',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Valider'), findsOneWidget);
    });

    testWidgets('SortiePrimaryButton renders in unbounded Row without layout error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SortieTheme.lightTheme,
          home: Scaffold(
            body: Row(
              children: [
                SortiePrimaryButton(
                  label: 'Bouton dans Row',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Bouton dans Row'), findsOneWidget);
    });

    testWidgets('SortiePrimaryButton supports mouse hover without MouseTracker assertion error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SortieTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: SortiePrimaryButton(
                label: 'Survol souris',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(const Offset(400, 300));
      await tester.pump();
      await gesture.removePointer();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
