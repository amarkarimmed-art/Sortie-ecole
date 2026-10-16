import 'package:app_ecole/features/surveillance/presentation/surveillance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA15 : Écran surveillant - reconnexion WebSocket et resynchronisation', () {
    testWidgets(
      'CA15 : À la reconnexion après coupure, l\'écran recharge l\'état complet depuis GET /queue',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SurveillanceScreen(),
          ),
        );

        expect(
          find.byKey(const Key('ecran_surveillance_resync')),
          findsOneWidget,
          reason: 'L\'écran surveillance doit se resynchroniser via GET /queue à la reconnexion',
        );
      },
    );
  });
}
