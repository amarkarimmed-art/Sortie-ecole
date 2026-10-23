import 'package:app_ecole/features/surveillance/domain/surveillance_item.dart';
import 'package:app_ecole/features/surveillance/presentation/widgets/child_call_card.dart';
import 'package:app_ecole/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChildCallCard — Flux à 2 étapes (« En chemin » -> « Remis »)', () {
    testWidgets('Rendu initial au statut requested : badge ambre et bouton En chemin', (tester) async {
      bool departCalled = false;

      final item = SurveillanceItem(
        requestId: 'req-123',
        childId: 'child-456',
        childInitial: 'Y.',
        childName: 'Yassine El Amrani',
        className: 'CE1 A',
        calledAt: DateTime(2026, 10, 5, 15, 30),
        status: 'requested',
        parentName: 'Fatima Zahra',
        parentUserId: 'user-789',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChildCallCard(
              item: item,
              onDepart: (id) async {
                departCalled = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vérification nom de l'enfant et classe
      expect(find.text('Yassine El Amrani'), findsOneWidget);
      expect(find.text('CE1 A'), findsOneWidget);

      // Vérification nom du parent
      expect(find.text('Parent : Fatima Zahra'), findsOneWidget);

      // Vérification badge ambre "Demandé / En classe"
      expect(find.text('Demandé / En classe'), findsOneWidget);

      // Vérification bouton "En chemin" avec clé 'bouton_parti_req-123'
      final buttonFinder = find.byKey(const Key('bouton_parti_req-123'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('En chemin'), findsOneWidget);

      // Clic sur "En chemin" -> passe en "on_the_way", le bouton devient "Remis" et le badge "En chemin vers le portail"
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(departCalled, isTrue);
      expect(find.text('En chemin vers le portail'), findsOneWidget);
      expect(find.text('Remis'), findsOneWidget);
    });

    testWidgets('Rendu au statut on_the_way : badge bleu et bouton Remis qui appelle onHandover', (tester) async {
      bool handoverCalled = false;
      String? handoverParentId;

      final item = SurveillanceItem(
        requestId: 'req-999',
        childId: 'child-888',
        childInitial: 'S.',
        childName: 'Sami Idrissi',
        className: '6eme A',
        calledAt: DateTime(2026, 10, 5, 15, 32),
        status: 'on_the_way',
        parentName: 'Karim Idrissi',
        parentUserId: 'parent-id-555',
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChildCallCard(
              item: item,
              onHandover: (id, {parentUserId}) async {
                handoverCalled = true;
                handoverParentId = parentUserId;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge bleu "En chemin vers le portail"
      expect(find.text('En chemin vers le portail'), findsOneWidget);

      // Bouton vert "Remis"
      final buttonFinder = find.byKey(const Key('bouton_parti_req-999'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('Remis'), findsOneWidget);

      // Clic sur "Remis"
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(handoverCalled, isTrue);
      expect(handoverParentId, 'parent-id-555');
    });
  });
}
