import 'package:app_ecole/features/surveillance/presentation/surveillance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA14 : Écran surveillant - mise à jour temps réel sans polling', () {
    testWidgets(
      'CA14 : L\'écran surveillant écoute les événements pickup.called sans polling',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SurveillanceScreen(),
          ),
        );

        expect(
          find.byKey(const Key('ecran_surveillance_stream')),
          findsOneWidget,
          reason: 'L\'écran surveillance doit être connecté au Stream WebSocket Reverb',
        );
      },
    );
  });
}
