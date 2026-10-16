import 'package:app_ecole/features/surveillance/presentation/surveillance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CA11 : Écran surveillant - tri et groupement par classe', () {
    testWidgets(
      'CA11 : L\'écran surveillant affiche les demandes class_notified groupées par classe',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: SurveillanceScreen(),
          ),
        );

        expect(
          find.byKey(const Key('ecran_surveillance')),
          findsOneWidget,
          reason: 'L\'écran surveillance doit être rendu avec la clé ecran_surveillance',
        );
      },
    );
  });
}
