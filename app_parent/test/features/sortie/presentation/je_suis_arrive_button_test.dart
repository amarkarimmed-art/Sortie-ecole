import 'package:app_parent/features/sortie/presentation/je_suis_arrive_button.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA11 : Tests d\'acceptation du bouton « Je suis arrivé » (Flutter)', () {
    final windowStart = DateTime(2026, 10, 5, 15, 20);
    final windowEnd = DateTime(2026, 10, 5, 16, 0);

    testWidgets('CA11.1 : Le bouton est désactivé avant l\'ouverture de la fenêtre', (tester) async {
      final beforeWindow = DateTime(2026, 10, 5, 14, 30);

      await withClock(Clock.fixed(beforeWindow), () async {
        var clicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JeSuisArriveButton(
                windowStart: windowStart,
                windowEnd: windowEnd,
                label: 'Je suis arrivé',
                onArrived: () => clicked = true,
              ),
            ),
          ),
        );

        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.enabled, isFalse);

        await tester.tap(find.byType(ElevatedButton));
        expect(clicked, isFalse);
      });
    });

    testWidgets('CA11.2 : Le bouton est activé pendant la fenêtre de sortie', (tester) async {
      final insideWindow = DateTime(2026, 10, 5, 15, 30);

      await withClock(Clock.fixed(insideWindow), () async {
        var clicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JeSuisArriveButton(
                windowStart: windowStart,
                windowEnd: windowEnd,
                label: 'Je suis arrivé',
                onArrived: () => clicked = true,
              ),
            ),
          ),
        );

        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.enabled, isTrue);

        await tester.tap(find.byType(ElevatedButton));
        expect(clicked, isTrue);
      });
    });

    testWidgets('CA11.3 : Le bouton est désactivé après la fermeture de la fenêtre', (tester) async {
      final afterWindow = DateTime(2026, 10, 5, 16, 15);

      await withClock(Clock.fixed(afterWindow), () async {
        var clicked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JeSuisArriveButton(
                windowStart: windowStart,
                windowEnd: windowEnd,
                label: 'Je suis arrivé',
                onArrived: () => clicked = true,
              ),
            ),
          ),
        );

        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.enabled, isFalse);

        await tester.tap(find.byType(ElevatedButton));
        expect(clicked, isFalse);
      });
    });

    testWidgets('CA11.4 : Libellé français correct', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          home: Scaffold(
            body: JeSuisArriveButton(
              windowStart: windowStart,
              windowEnd: windowEnd,
              label: 'Je suis arrivé',
            ),
          ),
        ),
      );

      expect(find.text('Je suis arrivé'), findsOneWidget);
    });

    testWidgets('CA11.5 : Libellé arabe avec support RTL correct', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: JeSuisArriveButton(
                windowStart: windowStart,
                windowEnd: windowEnd,
                label: 'وصلت إلى المدرسة',
              ),
            ),
          ),
        ),
      );

      expect(find.text('وصلت إلى المدرسة'), findsOneWidget);
    });
  });
}
